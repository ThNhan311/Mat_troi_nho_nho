# Kết quả R02 PT quản lý Availability

Ngày kiểm thử và review: 20/11/2026. R02 triển khai POST/PATCH/DELETE availability, dùng HTTP thật và PostgreSQL test riêng. Không phải E2E toàn hệ thống; không chạy frontend, Face Service, payment provider hoặc booking write.

## Đóng R01 và Git thực tế

Đã review đầy đủ 19 file R01, gồm untracked; scope chỉ backend tests/code và tài liệu bàn giao. Mười SHA256 executable sources khớp [evidence R01](R01_BOOKING_POLICY_READ.md); Surefire XML còn phù hợp: 300 tests, 0 failures/errors/skipped. Không thay executable source và không chạy lại full regression riêng để đóng R01. Sửa một bullet tài liệu backlog còn ghi “thống nhất” lifecycle thành triển khai D01–D07 đã chốt; không đổi contract/code đã test. Không phát hiện secret/token/mật khẩu thật, dữ liệu thật hoặc file Face trong scope.

Stage chính xác 19 file, không git add toàn workspace. Commit local R01: `9ae0a50593a921ae6c629c93bd9f36f0b373ace9`, message `feat(backend): add admin booking policy read API`, trên `feature/backend-booking-policy-read`, cha `073e131b718bdce780f338b69dd4c039b14644f9`. Kiểm tra tên nhánh R02 chưa tồn tại rồi tạo `feature/backend-pt-availability-write` từ commit này.

HEAD R02 vẫn `9ae0a50`; R02 chưa stage/commit. Không push/merge. Các untracked Face giữ nguyên; không reset/stash/merge hoặc sửa tài nguyên ngoài task. Không có AGENTS.md được tìm thấy trong cây repository hiện tại.

## Nguồn và hành vi đã triển khai

Đã đọc nội dung OOXML của Topic11_FITCENTER.docx người dùng cung cấp ngoài repository, đặc biệt UC-13 (1.5.4), auto-confirm/lifecycle (1.5.5–1.5.6), danh mục API (5.2), duration (6.3) và lock minh họa (7.2). Không giả định đã đọc bản này tại R01, không dẫn số trang chưa được kiểm chứng, không copy tài liệu nguồn vào Git. SHA256: `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`.

[Quyết định R02](../decisions/2026-11-20_R02_AVAILABILITY.md) phân biệt business với lựa chọn triển khai. Phương án DELETE đã được báo trước coding: soft disable thay hard delete vì V4 có FK ghép từ mọi booking, kể cả lịch sử. PATCH đổi giờ có lịch sử thì disable dòng cũ và tạo slot mới cùng transaction; trả ID mới, không sửa booking. GET PT hiện có giữ đường dẫn `/api/v1/pt/slots`; không thêm GET trùng chức năng theo đường dẫn gợi ý trong Topic11.

Ba API ghi: POST `/api/v1/pt/availability` 201; PATCH `/api/v1/pt/availability/{slotId}` 200; DELETE cùng item path 204/body rỗng. Chỉ ACTIVE PT có profile; resolve pt_id từ principal, không dùng ptId/status client. Slot mới và thời gian PATCH phải trong tương lai, session đúng 90 phút, precision không vượt microsecond; UTC response. PATCH chỉ sửa AVAILABLE chưa bắt đầu. Không overlap slot chưa DISABLED hoặc session CONFIRMED cùng PT, tiếp giáp được phép. BOOKED hoặc gắn CONFIRMED bị 409 dù status slot không nhất quán. Không re-enable DISABLED/slot đã qua.

Transaction khóa PT bằng FOR NO KEY UPDATE, rồi khóa slot sở hữu. Kiểm tra booked/CONFIRMED sau khóa. Query overlap cộng với exclusion constraint V4; concurrency/constraint/query-timeout failures dùng envelope 409 ERR_CONFLICT. DELETE không xóa row hoặc booking, lặp lại DISABLED trả 204. GET PT mọi trạng thái vẫn thấy DISABLED; danh sách MEMBER khả dụng không thấy. Chưa cần quyết định nghiệp vụ bổ sung để hoàn thành phạm vi đã giao.

## Diff thuộc R02

18 file: 7 production, 1 HTTP test và 10 tài liệu/OpenAPI. Ba production files mới:

- [PtAvailabilityWriteController](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/PtAvailabilityWriteController.java): đúng ba route ghi, không GET mới.
- [AvailabilityWriteRequest](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/request/AvailabilityWriteRequest.java): chỉ startAt/endAt.
- [AvailabilityWriteService](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/AvailabilityWriteService.java): validation, identity, transaction/locks, disable và thay thế bảo toàn lịch sử.

Bốn production files sửa: [PersonalTrainerRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/PersonalTrainerRepository.java), [AvailabilitySlotRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/AvailabilitySlotRepository.java), [BookingRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingRepository.java) thêm lock/query đọc, không booking write; [ApiExceptionHandler](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/exception/ApiExceptionHandler.java) thêm concurrency 409.

[HttpBaselineTest](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) thêm 59 test invocations, registry cleanup UUID riêng và hỗ trợ kiểm tra 204 rỗng. Không sửa fixture Task A, runner, API đọc, SecurityConfig, entity, POM, application properties hoặc migrations.

Tài liệu sửa: [API](../05_API_DOCUMENTATION.md), [testing](../06_TESTING_GUIDE.md), [business blockers](../07_BUSINESS_RULES_AND_BLOCKERS.md), [roadmap](../08_DEVELOPMENT_ROADMAP.md), [next tasks](../13_NEXT_DEVELOPER_TASKS.md), [harness](../14_HTTP_BASELINE.md), [OpenAPI](../api/openapi.yaml), [bổ sung nguồn D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md). Tài liệu mới: [quyết định R02](../decisions/2026-11-20_R02_AVAILABILITY.md) và báo cáo này.

## Tests thực sự chạy

JDK Temurin 21.0.13+9 đã xác minh; Maven Wrapper 3.10.0; JVM UTC. PostgreSQL 17.12, Docker local desktop-linux/npipe; container `fitcenter-baseline-20261120-db`, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, label task baseline-20261120, volume `fitcenter_baseline_20261120_data`, mapping `127.0.0.1:15437` → 5432. Target duy nhất: `fitcenter_baseline_20261120_test`, role `fitcenter_baseline_app` không superuser/createdb/createrole/replication/bypassrls. Xác minh target/container/mount/port/role/V1–V6 trước khi Spring/Flyway khởi động. Credentials test ngẫu nhiên chỉ trong process memory, không ghi token/mật khẩu thật vào source hoặc báo cáo.

| Lượt | Passed | Failed | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| HTTP focused đầu | 138 | 3 | 0 | 0 | 2026-11-20 10:37:20 |
| HTTP focused sau sửa fixture | 142 | 0 | 0 | 0 | 2026-11-20 10:38:59 |
| Full regression cuối | **359** | **0** | **0** | **0** | **2026-11-20 10:39:47** |

Ba failure đầu ở login của actor test thiếu profile: email local-part vượt 64 ký tự do nhãn quá dài, bị @Email từ chối 400. Sửa nhãn fixture thành email hợp lệ; thêm một ca ranh giới future một microsecond, rồi chạy lại focused/full. Không sửa production code sau các lượt test trên. Compile bằng JDK 21 đạt trước focused; wrapper cần quyền đọc cache ngoài sandbox. Không coi lỗi launcher/đường dẫn tạm là backend test case hoặc skipped.

Full 359 gồm 300 checkpoint R01 + 59 ca mới; focused 142 gồm 83 HTTP R01 + 59 ca mới, là tập con của full. Không cộng dồn các lượt. Full chạy 17 suites, bao gồm tests DB, context, service, security, MVC và HTTP. Class legacy tên DatabaseAlignmentTest chạy default profile trên cùng DB test canonical; không bật profile alignment. Không có V7 trong artifact/history.

Các ca R02 đã chạy:

- POST tạo đúng DTO/row UTC 90 phút; client giả ptId/status không đổi owner/status; đối chiếu GET PT hiện có và MEMBER availability; PT B không thấy slot PT A trong lịch riêng.
- PATCH giữ ID khi chưa có lịch sử; partial/no-op với offset tương đương; thay thế ID khi đổi giờ có CANCELLED, giữ nguyên toàn bộ booking/FK. Overlap khi sửa bị từ chối, dòng gốc không đổi.
- DELETE cho lịch sử CANCELLED/COMPLETED chuyển DISABLED, giữ nguyên mọi cột booking, không còn trong GET MEMBER khả dụng nhưng PT vẫn thấy DISABLED và MEMBER vẫn đọc được lịch sử. DELETE lặp lại 204 body rỗng.
- BOOKED không có booking row và AVAILABLE có CONFIRMED đều chặn PATCH/DELETE; CONFIRMED trên DISABLED vẫn chặn tạo slot overlap. Dữ liệu không nhất quán này cố ý kiểm tra phòng vệ service vì V4 cho phép.
- Overlap AVAILABLE/BOOKED cùng PT bị 409; PT khác được cùng giờ; hai khoảng tiếp giáp cả hai đầu hợp lệ; DISABLED không chặn công bố mới và không được PATCH mở lại; không sửa slot quá khứ thành tương lai.
- POST sai quá khứ/bằng now/đảo giờ/zero/60 hoặc 120 phút/nanosecond quá precision/thiếu field/thiếu offset/format sai trả 400. Future đúng một microsecond hợp lệ. PATCH empty/duration sai/past/format sai trả 400 và row không đổi.
- Role ADMIN/MEMBER 403, anonymous 401 trên cả ba methods; tài khoản PT SUSPENDED/DISABLED với token đã phát hành 401; ACTIVE PT thiếu profile 404; ownership PT A/B và missing slot 404 trên PATCH/DELETE.
- Concurrency tạo chồng 2/8/20 requests: mỗi đợt đúng một 201, còn lại 409 ERR_CONFLICT, DB đúng một slot trong khoảng. Race PATCH/POST vào cùng khoảng: đúng một thay đổi thành công, còn lại 409. Response/correlation/payload/status và DB được kiểm tra, không chỉ HTTP 200.
- Hai ca PATCH/DELETE: kết nối SQL riêng giữ slot FOR UPDATE, quan sát HTTP connection chờ Lock qua pg_stat_activity; SQL insert CONFIRMED rồi commit; HTTP chờ xong trả 409 và slot/booking giữ nguyên. Đây là kiểm thử giao thức khóa, chưa phải booking endpoint.

OpenAPI parse/structure và 94 local references đạt (15 paths). Kiểm tra availability chỉ POST tại collection, item chỉ PATCH/DELETE + path parameter, policy vẫn GET-only, auth/error contract, DTO và 204 không có body. Dùng SnakeYAML 2.6 cached với JDK 21; không tuyên bố đã dùng OAS validator chuyên dụng. Diff whitespace và link nội bộ được kiểm tra riêng.

Hậu kiểm users/members/trainers/plans/memberships/slots/bookings/policy/notifications đều 0 dòng, bằng trước khi chạy; migration history vẫn chính xác V1–V6, tất cả success. Cleanup theo UUID, không truncate/xóa dữ liệu ngoài fixture. DB test được dừng sau nghiệm thu, giữ nguyên named volume. Không dùng onboarding BLOCKED, profile alignment, Flyway clean/repair, không sửa/áp migration mới.

## Chạy lại và giới hạn

Theo [hướng dẫn harness](../14_HTTP_BASELINE.md), chọn JDK 21 và kiểm tra container/volume/port/test DB. Từ repository root, cấp mật khẩu role test qua prompt an toàn hoặc process environment, không đưa vào command line/Git:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase -FullSuite
```

ExecutionPolicy Bypass chỉ áp dụng child process, không đổi policy máy. Runner yêu cầu booking_policy trống cho scenarios R01; nếu có dữ liệu thì dừng, không tự xóa. Test scripts chỉ chạy trên DB riêng đã xác minh; raw confirmation dùng JDBC test trong suite, không thêm endpoint hỗ trợ tests.

Chưa có booking API để kiểm thử race end-to-end với availability API. Booking write tương lai phải dùng slot lock, kiểm tra lại AVAILABLE và cùng thứ tự khóa khi dùng PT + slot. V4 không tự cấm mọi SQL writer tùy ý chèn CONFIRMED vào DISABLED; xem [giao thức/giới hạn](../decisions/2026-11-20_R02_AVAILABILITY.md). Không tuyên bố R02 bảo vệ writer bỏ qua giao thức này. Không load/performance test hoặc chạy frontend/Face/payment.

D01 membership/eligibility/recheck, D02 limits áp dụng vào booking, D03 ranh giới notice/advance/cancel, phần từ chối booking khi thiếu policy D04, policy write D05, booking-time calculation D06 và cancel/complete D07 chưa triển khai. Auto-confirm booking chưa có. R01 policy GET/equality/UTC vẫn hoạt động; R02 chỉ availability và fixture/locks. Không thêm PENDING/REJECTED, scheduling/versioning hoặc V7.

## Source working tree đã test

SHA256 là bytes executable sources của lượt full 359; docs hoàn thiện sau test, source không đổi. Khi stage tương lai có thể đổi LF/CRLF mà không đổi Java semantics.

| File | SHA256 |
|---|---|
| ApiExceptionHandler.java | `72C3CD36445732A2D0989FC9DF04232A4A108079AB34339692E5590AB978AEDC` |
| AvailabilitySlotRepository.java | `E35BD38DFA3F4A16E843B07500C4BC8A645979544E74510011E90F40D6D84C0A` |
| BookingRepository.java | `263DD2A9CAE62E29E806E61C53E95D6AAA2CFB73AE385C0BF76C174A700AAD62` |
| PersonalTrainerRepository.java | `66E534F8ECCBC8B8F3A5CB0AE03822A8116DBDF8BC1E0610C04E2C1F600C1C27` |
| HttpBaselineTest.java | `065B51C0BB53E3AF4DF89711356BFFFC675B60FC383DC906D1EFC3A832DA7C6C` |
| PtAvailabilityWriteController.java | `4B3C4A7D31D5EE9AA6DD3594ABD8699B4C8D6561E5D84F1ED7F51C90BF5B6936` |
| AvailabilityWriteRequest.java | `B89FFF74FA492006CB93E0F8E036AF5D63AEC99D36F58105785420648FB56C4A` |
| AvailabilityWriteService.java | `9DC69CA8416DB1093D37D1A7D76D93840576D63A9FE4851EA41E8EBFB340FA6C` |
