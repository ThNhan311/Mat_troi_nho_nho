# Kết quả R01 Admin đọc Booking Policy

Ngày nghiệm thu working tree: 20/11/2026. R01 chỉ thêm GET `/api/v1/admin/booking-policy`, không triển khai policy write hoặc booking lifecycle. Đây là unit/HTTP integration với PostgreSQL riêng, không phải E2E toàn hệ thống.

## Git và đóng Task A

Task A đã được review toàn bộ năm file, gồm untracked, và đối chiếu ba SHA256 executable files với bằng chứng 285 tests. Không phát hiện secret/token/mật khẩu cố định, dữ liệu thật hoặc file Face trong phạm vi stage. Không thay code Task A trước commit nên không chạy lại full suite cho bước đóng Task A.

Commit local Task A: `073e131b718bdce780f338b69dd4c039b14644f9`, message `test(backend): add reproducible HTTP baseline fixtures`, trên nhánh `feature/backend-http-baseline-fixtures`. Chỉ stage chính xác năm file được review, không git add toàn bộ workspace.

R01 được tạo từ commit này trên nhánh `feature/backend-booking-policy-read`; HEAD vẫn `073e131`. R01 chưa stage/commit. Không push, merge hoặc sửa môi trường Face untracked.

## Hành vi và diff R01

- Sáu production files mới: [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/AdminBookingPolicyController.java), [entity immutable](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/domain/entity/BookingPolicy.java), [DTO](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingPolicyResponse.java), [repository chỉ đọc](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyRepository.java), [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyService.java) và [exception](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/exception/BookingPolicyNotFoundException.java).
- [ApiExceptionHandler](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/exception/ApiExceptionHandler.java) thêm handler riêng HTTP 404/code BOOKING_POLICY_NOT_FOUND, dùng envelope và correlation ID hiện hữu. Các mã lỗi khác giữ nguyên.
- SecurityConfig không đổi: matcher `/api/v1/admin/**` đã yêu cầu ADMIN. Không token trả 401, MEMBER/PT trả 403 trước controller/service.
- Service lấy now từ Clock cho mỗi lần đọc, query `active=true AND effective_from <= now`, transaction read-only. DTO gồm ID, bốn giới hạn và effectiveFrom kiểu Instant, JSON UTC. Không tìm thấy thì 404, không fallback, seed hoặc UPDATE; repository không cung cấp save/delete.
- Thêm BookingPolicyServiceTest; mở rộng HttpBaselineTest bằng test Clock kiểm soát và 12 test invocations R01. Test Clock được import trong test configuration, reset sau mỗi ca và không vào production.
- Fixture PT hủy đổi slot từ AVAILABLE sang DISABLED theo D07; expectations availability cập nhật tương ứng. Đây chỉ là dữ liệu đọc, không triển khai cancel service.
- Cập nhật API/JSON schema, hướng dẫn test, trạng thái roadmap/backlog và [D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md). Phạm vi diff cuối: 7 production files, 3 test/fixture files, 9 tài liệu/OpenAPI; không thay POM, application properties hoặc migrations.

## Kết quả vừa chạy

Môi trường: Temurin 21.0.13, Maven Wrapper 3.10.0, JVM UTC; PostgreSQL 17.12. Docker context desktop-linux local; container `fitcenter-baseline-20261120-db`, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, named volume `fitcenter_baseline_20261120_data`, mapping `127.0.0.1:15437`. Target duy nhất là `fitcenter_baseline_20261120_test` bằng role `fitcenter_baseline_app` không superuser; xác minh role/schema/URL/history trước Spring/Flyway.

| Lượt | Passed | Failures | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| BookingPolicyServiceTest focused | 3 | 0 | 0 | 0 | 2026-11-20 10:12:15 |
| HttpBaselineTest focused | 83 | 0 | 0 | 0 | 2026-11-20 10:14:58 |
| Full regression với DB/context + HTTP | 300 | 0 | 0 | 0 | 2026-11-20 10:16:34 |

83 HTTP/fixture invocations gồm 71 của Task A đã điều chỉnh fixture D07 và 12 ca R01. Full gồm 285 của Task A cộng 12 ca HTTP và 3 unit mới. Không cộng các focused runs vào full, không gọi 300 là số HTTP requests. Surefire XML hiện hành nằm ở backend/target/surefire-reports và được gitignore.

12 ca HTTP R01: ADMIN đọc policy đã hiệu lực, đọc bộ giá trị khác 14/2/4/5, equality effective_from=now; absent/inactive/future trả 404; inactive cũ không fallback khi active còn tương lai; bốn actor MEMBER A/B/PT A/B bị 403; anonymous bị 401. Assertions kiểm tra sáu trường DTO, dữ liệu thật đã seed, ISO-8601 UTC từ input offset +07:00, ranh giới một microsecond, status/error code/envelope/header-body correlation và row không thay đổi sau GET.

Ba unit cases kiểm tra mapping giá trị DB với Clock fixed, không fallback khi thiếu và re-evaluate Clock ở từng lần đọc. Full regression tiếp tục chạy toàn bộ test hiện hữu và Hibernate schema validation với entity mới.

OpenAPI YAML parse và toàn bộ 70 local references đạt; kiểm tra path policy chỉ có GET, các response 200/401/403/404/500 và sáu required DTO fields đạt. Đây là kiểm tra syntax/structure/refs bằng SnakeYAML trong dependency cache, không tuyên bố đã dùng validator OAS chuyên dụng. Whitespace/source-scope và link tài liệu được review riêng.

Hậu kiểm: booking_policy, users, bookings, availability_slots và notifications đều 0 dòng, bằng trước lượt chạy; fixture không để lại policy/default. Flyway history vẫn đúng V1–V6, tất cả success; không áp V7, alignment, repair/clean hoặc onboarding scripts BLOCKED. Container thử được dừng sau nghiệm thu, volume giữ nguyên; không thay tài nguyên ngoài task.

## Working tree được test

SHA256 dưới đây là bytes source đã chạy, trước chuyển đổi LF/CRLF nếu stage sau này. Tài liệu được hoàn thiện sau test không đổi executable sources.

| File | SHA256 |
|---|---|
| AdminBookingPolicyController.java | `9D5A4211A0D1B169CB8D389799FC4DCFD81B35DF9EB3BC34A81CCBE06419A668` |
| BookingPolicy.java | `FAD9668C03E78952819FCA3327B716DC2D83FE55B46E164A07F840B7E58D20CF` |
| BookingPolicyResponse.java | `D97D1EBF4A1EEA4454DB451A0CAFA90D98CD8E04B4FD3C047A5E24AAF8B2A8BB` |
| BookingPolicyNotFoundException.java | `7150A02C2B0A00ED0948C20107A9E6C2A66DBF2223AA5F6E11A417110D632092` |
| ApiExceptionHandler.java | `DBF6CD86E708C8F8B4A6106D6002474BD9427C2056009FA08BCE4E3F50AC1EFE` |
| BookingPolicyRepository.java | `2AF0DAC8316EA2F822A1F96E1BF89D7E7172D1BBB2E174A9F8336CC1ACC26416` |
| BookingPolicyService.java | `0B04FD3F9AEA0A438CE079D169D8EE1F45FD0D4C17B203E184CBD0F01A39A435` |
| BookingPolicyServiceTest.java | `ECDF3AD55675550C7FFCBDB894268C16F7A8A4E9E2E4507F345329D4A7405894` |
| HttpBaselineFixture.java | `14C5ED3FF65683A0AD0C54D0E17CDEB6239A8D3606357D92E5F1E139935F39A4` |
| HttpBaselineTest.java | `2D2811C2DD406CFB2482B3F1990093DCD64D9F7F87C9A79EAE9594553064BEC8` |

## Phần chưa triển khai và giới hạn

[Sổ quyết định](../decisions/2026-11-20_BOOKING_DECISIONS.md) phân biệt phê duyệt với code. Nguồn Topic11 của auto-confirm được ghi theo xác nhận người dùng; chưa có bản Topic11 trong checkout để audit nguyên gốc hoặc dẫn trang.

Chưa triển khai tạo booking auto-confirm; membership ACTIVE/bao phủ session/kiểm tra trước dịch vụ (D01); áp 14/2/4/5 và ranh giới advance/notice/cancel/count vào booking (D02/D03/D06); từ chối booking do thiếu policy (phần booking của D04); PUT policy có hiệu lực ngay (D05); PT cancel/complete và đồng bộ slot (D07). Scheduling và quản lý phiên bản đầy đủ tiếp tục hoãn. Không thêm PENDING/REJECTED.

Không tự tạo policy ban đầu. Trên DB chưa có policy hiệu lực, ADMIN nhận 404 cho đến khi có dữ liệu được cấp theo một quy trình riêng được phép. HTTP scenarios yêu cầu booking_policy ban đầu trống trên DB test riêng và dừng nếu đã có dữ liệu; không tự xóa policy của người khác. Cleanup/giới hạn JVM bị kill giữ nguyên như [hướng dẫn harness](../14_HTTP_BASELINE.md).

Chạy lại theo [testing guide](../06_TESTING_GUIDE.md): focused unit không cần DB; focused HTTP hoặc -FullSuite dùng runner Task A và guard tài nguyên. Không đổi default Java hệ thống, không chia sẻ process environment, token, mật khẩu hoặc docker inspect đầy đủ.
