# Kết quả Admin Booking Policy write

Ngày thực hiện: 20/11/2026. PUT `/api/v1/admin/booking-policy` đã triển khai và kiểm thử trên JDK 21/PostgreSQL riêng. Đây là unit + HTTP/DB integration/concurrency; không phải E2E toàn hệ thống. D01 service-start eligibility check vẫn chưa triển khai.

## Đóng R04 và Git

Review đủ 19 file R04 gồm untracked, API/OpenAPI/quyết định/code/tests/evidence; cả 9 executable source hashes khớp [báo cáo R04](R04_BOOKING_LIFECYCLE.md). XML tại lúc đóng vẫn 543 passed, 0 failures/errors/skipped, 19 suites. Sửa một câu tài liệu API còn ghi PT cancel chờ quyết định để đồng nhất với code và phần đầu tài liệu; không đổi executable source nên không chạy lại full chỉ để commit. Không phát hiện secret/mật khẩu/token thật, dữ liệu thật hoặc Face trong phạm vi được stage.

Stage chính xác 19 file, không git add toàn workspace; commit local `8cb95e23a9fbf357ce452bdb1bdeecaa4db824c0`, message `feat(backend): add booking cancellation and completion`, cha `394a21f96c7c7458cc109c9f56a174beb1ccf62b`. Kiểm tra tên nhánh policy write chưa tồn tại rồi tạo `feature/backend-booking-policy-write` từ commit này. HEAD hiện tại `8cb95e2`; task policy write chưa stage/commit, không push/merge/reset/stash. Giữ nguyên untracked Face và tài nguyên ngoài task. Không tìm thấy AGENTS.md trong cây/ancestors đã kiểm tra.

## Nguồn, contract và tác động

Đọc Topic11_FITCENTER.docx ngoài repo do người dùng cung cấp: UC-22 trong bảng use cases, mục 6.5 Admin Booking Policy Form; đọc OOXML, không suy ra trang. SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`. Mục 6.5 có bốn giới hạn và UI Effective From/không hồi tố invalid booking CONFIRMED. D05 và task người dùng giới hạn immediate update, hoãn scheduling/versioning đầy đủ. Đối chiếu D01–D07, V4, read R01, create R03 và lifecycle R04. Không copy tài liệu nguồn vào Git.

[Contract/quyết định/traceability](../decisions/2026-11-20_BOOKING_POLICY_WRITE.md) được ghi/báo trước coding. PUT chỉ ADMIN ACTIVE, body đúng bốn JSON integer fields: maxAdvanceDays>=1, minNoticeHours>=0, cancelDeadlineHours>=0, maxFutureBookings>=1. Miền trên là INTEGER signed 32-bit hiện có, không thêm business cap/quan hệ fields. Reject thiếu/null/sai kiểu, string/decimal coercion, extra fields gồm effectiveFrom; không nhận lịch tương lai/hồi tố. 14/2/4/5 chỉ là fixture/ví dụ. 200 DTO R01 sáu fields; effectiveFrom do Clock sau chờ khóa, truncate microseconds, UTC. Role/account/validation/constraint errors dùng envelope/correlation hiện hữu, không SQL/stack trace hoặc retry mù.

UPDATE active tại chỗ giữ ID (kể cả active tương lai sẽ thành hiệu lực ngay); chưa có active thì INSERT UUID mới, kể cả bảng trống/chỉ inactive. Ghi updated_by từ ADMIN principal; giữ nguyên inactive rows. Không lưu lịch sử từng lần sửa active, không snapshot policy theo booking, không phải full versioning. Entity/repository đọc R01 vẫn immutable/read-only; JDBC write riêng dùng cùng datasource/transaction manager. Không sửa V1–V6 hoặc áp V7, dependency, entity/POM, profile, runner, fixture class hoặc onboarding BLOCKED.

Giới hạn mới dùng cho create tiếp theo; giảm maxFutureBookings không tự hủy/sửa booking/slot cũ. Member cancel vẫn đọc deadline hiệu lực **lúc yêu cầu hủy**, kể cả booking tạo trước PUT; tăng/giảm cancelDeadlineHours có thể từ chối/cho phép yêu cầu hủy sau cập nhật. Không hồi tố đổi state/time/owner của booking. Đây là hành vi R04/người dùng yêu cầu giữ, không tự chuyển sang snapshot deadline lúc đặt. D01 service-start check, membership/payment write và Face ngoài phạm vi.

## Transaction và phạm vi diff

READ_COMMITTED, timeout 10 giây. Exclusive PostgreSQL transaction advisory lock `(20261120,22)` cho PUT trước chọn active/Clock/write; shared cùng key cho GET và policy reads R03/R04 trước Clock/query. Khóa có hiệu lực cả bảng trống, giải phóng khi commit/rollback. Hai PUT hợp lệ có thể đều 200, **last-write-wins theo thứ tự lấy khóa/commit**, không hứa thứ tự request đến, không bắt thêm version field. Partial unique index V4 chặn nhiều active như lớp cuối.

R03: Member→membership→PT→slot→policy shared; validate membership trước lookup policy với cùng locked time sample. R04 Member cancel: Member→PT→slot→booking→policy shared. PUT chỉ khóa policy exclusive/ghi policy, không khóa Member/membership/PT/slot/booking; không đảo giao thức R02/R03/R04 hoặc tạo chiều ngược. Readers chờ PUT xong rồi mới lấy Clock để không dùng mốc cũ với row policy vừa thay. GET và booking đọc trọn một DTO, không trạng thái nửa cập nhật. PT cancel/complete không đọc policy và giữ Clock sau row locks như R04.

21 file thuộc task: 8 production, 3 tests, 10 tài liệu/OpenAPI.

- Production sửa: [Admin controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/AdminBookingPolicyController.java), [policy read service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyService.java), [R03 create](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingCreateService.java), [R04 lifecycle](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleService.java).
- Production mới: [request/strict local decoder](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingPolicyWriteRequest.java), [policy lock](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyLock.java), [write repository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyWriteRepository.java), [write service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyWriteService.java). Không đổi Jackson coercion toàn ứng dụng.
- Tests: [policy read unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingPolicyServiceTest.java), [policy write unit mới](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingPolicyWriteServiceTest.java), [HTTP/DB harness](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java).
- Docs sửa: [API](../05_API_DOCUMENTATION.md), [testing](../06_TESTING_GUIDE.md), [blockers](../07_BUSINESS_RULES_AND_BLOCKERS.md), [roadmap](../08_DEVELOPMENT_ROADMAP.md), [next tasks](../13_NEXT_DEVELOPER_TASKS.md), [harness](../14_HTTP_BASELINE.md), [OpenAPI](../api/openapi.yaml), [D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md); mới [quyết định/traceability](../decisions/2026-11-20_BOOKING_POLICY_WRITE.md) và báo cáo này.

## Môi trường và kết quả thực chạy

Temurin JDK 21.0.13+9, Maven Wrapper 3.10.0, JVM UTC; không dùng Java 25 mặc định máy. PostgreSQL 17.12 trên local Docker desktop-linux `npipe:////./pipe/dockerDesktopLinuxEngine`. Container `fitcenter-baseline-20261120-db`, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, label fitcenter.task=baseline-20261120, named volume `fitcenter_baseline_20261120_data`, loopback `127.0.0.1:15437`→5432. DB riêng `fitcenter_baseline_20261120_test`; app role `fitcenter_baseline_app` không superuser/createdb/createrole/replication/bypassrls. Xác minh engine/container/mount/port/readiness/DB/role/history V1–V6 trước Spring/Flyway. Credentials/JWT sinh ngẫu nhiên trong process memory, không in/lưu giá trị thật. Runner guard hiện có được giữ nguyên.

| Lượt thực chạy | Passed | Failed | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| Unit R01 sau compile read lock, trước khi thêm tests mới | 3 | 0 | 0 | 0 | 2026-11-20 15:43:54 |
| Unit policy read/write focused | 11 | 0 | 0 | 0 | 2026-11-20 15:49:00 |
| HTTP/DB focused đầu, Admin B fixture email invalid | 346 | 4 | 0 | 0 | 2026-11-20 15:49:58 |
| **HTTP/DB focused cuối sau sửa fixture** | **350** | **0** | **0** | **0** | **2026-11-20 15:51:31** |
| **Full regression source cuối** | **618** | **0** | **0** | **0** | **2026-11-20 15:53:09** |

Failure đã sửa: nhãn policy-admin-b làm email tổng hợp có local part dài 65 ký tự, login trả 400 validation trước khi bốn ca cạnh tranh tới PUT. Rút gọn thành policy-b (59 ký tự); không sửa login/validation nghiệp vụ. Bốn ca trước sửa **chưa thực thi PUT race**, không được gọi đã đạt. Focused cuối chạy lại toàn harness và đạt; full cuối cùng source cũng đạt. Không có failure còn mở hoặc skipped, không dùng kết quả R04 lịch sử làm kết quả PUT vừa chạy.

Full **618 = 543 R04 + 67 HTTP/DB cases mới + 8 unit invocations mới**. Unit focused 11 gồm 3 cũ, 1 read-lock unit mới, 7 write-service units. Harness cuối 350 = 283 R04 + 67 mới; một case R04 là service/DB rollback trực tiếp, các ca policy rollback kết hợp service write trong transaction với reader HTTP thật. Không gọi 350 là số HTTP requests. Surefire 20 XML suites, HttpBaselineTest một XML 350 testcase. Console nested 209 gồm 142 cũ+67 mới, create 56 và lifecycle 85, outer 0; không cộng lại outer/nested. Focused/full/lượt sửa là tập con/lặp, không cộng dồn. DatabaseAlignmentTest legacy chạy default V1–V6, không dùng profile alignment.

Phạm vi assertions thực chạy:

- ADMIN explicit first configuration, update giữ ID, GET đủ sáu fields/values/UTC/effectiveFrom; updated_by đúng actor. Chỉ inactive thì giữ full row snapshot và insert active mới; active tương lai được PUT thành immediate. Clock nanosecond truncate microseconds, không nhận thời gian client.
- 41 validation invocations: bốn fields thiếu/null/dưới min/string/decimal/boolean/array/object/INTEGER overflow, effectiveFrom hồi tố/tương lai, missing/root array/string body. Mỗi ca 400 ERR_VALIDATION và full policy row không đổi. Lowest bounds 1/0/0/1, max INTEGER và quan hệ fields không bị tự hạn chế được chấp nhận.
- MEMBER/PT bốn accounts 403, anonymous 401, Admin SUSPENDED/DISABLED dùng token cũ 401. Admin mất ACTIVE trong lúc chờ khóa trả 403, không tạo policy. PUT chờ khóa lấy Clock mới sau chờ.
- Hai ADMIN khác nhau (BCrypt encoder thực, example.invalid, password/token chỉ trong memory): cùng chờ lock trước release, bốn races empty/existing/đảo actor; cả hai 200, đúng một active, cùng ID và toàn bộ values/updated_by từ writer cuối, không mix fields.
- GET chờ writer transaction chưa commit; JDBC connection khác vẫn thấy trọn cấu hình cũ/không có row. Sau commit GET đủ cấu hình mới; rollback first insert/update trả về cấu hình cũ/404 và full rows nguyên trạng. SQL writes đã được quan sát trong writer transaction trước rollback; không thêm trigger/schema/test endpoint hoặc giả là HTTP writer failure.
- Create sau PUT áp custom advance/notice, equality ở 2 ngày/48 giờ được đặt 201; slot BOOKED. Giảm future limit không đổi full booking/slot snapshots, chỉ chặn booking mới ERR_MAX_FUTURE_BOOKINGS. Booking cũ sau PUT deadline tăng bị từ chối hủy, giảm về equality được CANCELLED/slot AVAILABLE, không đổi booking khi PUT tự chạy.
- Booking create/Member cancel được gửi lúc PUT giữ transaction, quan sát đang chờ shared policy lock, dịch Clock rồi commit: requests dùng cấu hình mới và đúng lỗi notice/deadline; không mutation slot/booking khi bị từ chối. Không deadlock với row locks R03/R04. Full giữ toàn bộ R03/R04 concurrency/ownership/rollback regression.

Cleanup theo registry UUID policy/booking/slot; Admin B xóa đúng UUID, khôi phục Admin A status, không truncate/broad delete. Hậu kiểm users/members/trainers/plans/memberships/slots/bookings/policy/notifications đều 0 như trước test; history đúng 1–6 success. Dừng đúng DB test riêng sau nghiệm thu, giữ named volume; không đụng tài nguyên dùng chung.

OpenAPI YAML/structure đạt **19 paths, 130 local references** bằng SnakeYAML 2.6 cached/JDK 21; kiểm GET+PUT policy, auth/responses/strict request bốn fields/min/max/int32/no client time và regression R02/R03/R04. Không tuyên bố đã chạy OAS validator chuyên dụng. Docs hoàn thiện sau full, không đổi executable source; whitespace, relative links, scope và credential patterns được review riêng.

## Chạy lại và giới hạn

Theo [testing guide](../06_TESTING_GUIDE.md), [runner guide](../14_HTTP_BASELINE.md), xác minh JDK21/container ID/label/volume/port/DB/role trước Spring/Flyway. Cấp credentials role test bằng secure prompt hoặc process environment; không hardcode/đưa giá trị thật lên command line/Git. Password ngẫu nhiên cũ không giữ trong repo: nếu cần, cấp lại qua quyền quản trị **đúng test DB đã xác minh**. Thay JAVA_HOME/PATH chỉ trong process.

```powershell
# Từ backend, JDK 21; unit không cần DB:
.\mvnw.cmd -B -ntp '-Dtest=BookingPolicyServiceTest,BookingPolicyWriteServiceTest' test

# Từ repository root, focused rồi full khi cần:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase -FullSuite
```

Bypass chỉ child process, không đổi execution policy máy. Runner dừng DB nếu nó đã khởi động; nếu DB chạy từ bước chuẩn bị, sau tests dừng đúng container đã kiểm tra và giữ volume. Không chạy onboarding BLOCKED/alignment/V7. Không có blocker schema hoặc quyết định nghiệp vụ mới cho phạm vi PUT. Last-write-wins/snapshot dựa vào writers/readers tuân thủ advisory protocol; index V4 vẫn chặn nhiều active cho writer ngoài protocol. Không có full version history/audit trail từng thay đổi, scheduling, If-Match hoặc endpoint version bắt buộc. Không benchmark hoặc frontend/Face/payment/E2E toàn hệ thống. D01 service-start check vẫn chưa triển khai; task policy write giữ chưa stage/commit cho review.

## SHA256 executable source của working tree đã full-test

Base commit `8cb95e23a9fbf357ce452bdb1bdeecaa4db824c0` + 11 file dưới đây; docs/OpenAPI có thể hoàn thiện sau full nhưng executable source không đổi.

| File | SHA256 |
|---|---|
| backend/src/main/java/vn/edu/tdtu/fitcenter/controller/AdminBookingPolicyController.java | FBEA01A07364DF225670986BD28C6E16F230042F223B9871B13584741537B8D4 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingCreateService.java | 7CC3E87B4C00514B85D68A5C01F43B4061C1DFB23B11C6C762B1FA0BDCC99B1C |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleService.java | 36F96408D81F361EED5500B8CA3535340A716D90ACC677054D1E562C91A1E85E |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyService.java | 74DFACE9766220C0087F64214E966D640C18AB703B8E25883726DA65F1768D5F |
| backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java | D3D8011773375ACECE602DA21AC286799AF394B1D6EFB7571BF501B679DA99C9 |
| backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingPolicyServiceTest.java | 9756E89F1F6A0E12CFDC6E3676A8941BC9DFD0B45B1880FDE6980E57A8CB7455 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingPolicyWriteRequest.java | E2A3A955009285D34D311C59A4A0FC65C72EDFC0128BAC2F799E70716B0ACDAA |
| backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyLock.java | DBEFCDBA5C0EE9433946C33533B69BDC43A0B78F133ED58C86D182B098DB2643 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyWriteRepository.java | CDC64FF96ACD42C0DAFF8AD145C106B03F0630B7525B6FBC3ABFAD4E0A80B78A |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyWriteService.java | AA77D7878BD0CF36B33A9E9581EFC7153A80A40CE45E74CB9F62CB4DCAF17ECF |
| backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingPolicyWriteServiceTest.java | E249124B7D7C4F47A291E9A5AA9E55412D1F070A42809D99D7A6A9D520FBF971 |
