# Kết quả R03 Member tạo booking auto-confirm

Ngày kiểm thử/review: 20/11/2026. R03 triển khai POST `/api/v1/bookings` với HTTP thật, PostgreSQL riêng và JDK 21. Đây là unit/HTTP integration + DB concurrency, không phải E2E toàn hệ thống; không chạy frontend, Face Service hoặc payment provider.

## Đóng R02 và Git

Review đầy đủ 18 file R02 gồm untracked, diff code/tests/docs và [evidence R02](R02_PT_AVAILABILITY_WRITE.md). Tám executable source hashes khớp evidence; Surefire XML vẫn 359 tests, 0 failures/errors/skipped. Tài liệu mô tả rõ DELETE → DISABLED/204, PATCH đổi giờ có lịch sử có thể trả slot thay thế ID mới. Không phát hiện secret/token/mật khẩu thật, dữ liệu thật hoặc file Face trong phạm vi. Source không đổi nên không chạy lại full chỉ để đóng R02.

Đã stage chính xác 18 file, không git add toàn workspace, tạo commit local `4d137d703ab522e6f977d0e297f5a939a1011bcc`, message `feat(backend): add PT availability write APIs`, trên feature/backend-pt-availability-write, cha `9ae0a50593a921ae6c629c93bd9f36f0b373ace9`. Kiểm tra nhánh R03 chưa tồn tại trước khi tạo `feature/backend-booking-create` từ commit R02.

HEAD hiện tại vẫn `4d137d7`; R03 chưa stage/commit, không push/merge. Giữ nguyên untracked Face, không reset/stash/merge hoặc sửa tài nguyên ngoài task. Không tìm thấy AGENTS.md trong cây repository đã kiểm tra.

## Nguồn, quyết định và triển khai

Đã đọc lại Topic11_FITCENTER.docx đính kèm ngoài repository, SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`, đặc biệt UC-10 (1.5.5), API 5.3 và lock minh họa 7.2; đối chiếu D01–D07, V2/V4, R01 policy và giao thức R02. Đọc nội dung OOXML, không giả định số trang. Không copy tài liệu nguồn vào Git.

Phương án transaction/lock đã được báo trước coding: Member → membership hiện hành → PT → slot, bảo vệ count/overlap Member qua các slot khác nhau, giữ PT → slot của R02. Khoảng DATE membership theo Việt Nam inclusive expiry đã được nêu trước coding. Review bổ sung READ_COMMITTED khai báo rõ để các lần đọc sau chờ khóa thấy dữ liệu mới commit; không dựa vào isolation mặc định. Timeout 10 giây, không retry mù hoặc thêm dependency/Redis.

POST nhận ptId/slotId UUID, chỉ MEMBER ACTIVE có profile; member_id từ principal. PT ACTIVE khớp slot; slot AVAILABLE, không có CONFIRMED, đúng 90 phút, version không đổi khi chờ. Dùng policy R01 tại cùng mẫu Clock, không default. ACTIVE membership phải có hiệu lực hiện tại và bao phủ session theo ngày Asia/Ho_Chi_Minh; session kết thúc đúng 00:00 ngày sau expiry hợp lệ, vượt một microsecond bị từ chối. Notice/advance equality hợp lệ; ngày advance là thời lượng 24 giờ. Count CONFIRMED có start_at>now của Member, count hiện có >= limit thì reject. Overlap Member/PT trên `[start,end)`; tiếp giáp cho phép.

Flush slot BOOKED và INSERT CONFIRMED nguyên tử, lấy time/PT từ slot đã khóa, không tin owner/status client. HTTP 201 trả BookingResponse hiện hữu với `id`, owner/PT/slot/time UTC, status CONFIRMED và bốn trường cancellation/completion null. Không thêm PENDING/REJECTED/PT approval. Lỗi có error envelope/correlation; mất slot/đổi version dùng 409 ERR_SLOT_NO_LONGER_AVAILABLE, business conflict có mã riêng, DB/lock conflict 409 ERR_CONFLICT. Thiếu policy dùng nguyên 404 BOOKING_POLICY_NOT_FOUND của R01, không seed hoặc fallback.

[Quyết định R03 và traceability](../decisions/2026-11-20_R03_BOOKING_CREATE.md) phân biệt yêu cầu nghiệp vụ với lựa chọn khóa/version/DATE/DTO. [API documentation](../05_API_DOCUMENTATION.md) có input/response, mã lỗi và giới hạn; không có blocker schema yêu cầu migration cho phạm vi đã chốt.

## Diff thuộc R03

25 file: 13 production, 2 test và 10 tài liệu/OpenAPI. Năm production files mới:

- [BookingCreateController](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/BookingCreateController.java): POST duy nhất, @Valid, HTTP 201; không đổi controller GET/MVC hiện hữu.
- [BookingCreateRequest](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingCreateRequest.java): hai UUID @NotNull.
- [BookingCreateService](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingCreateService.java): transaction/locks, recheck sau chờ, BOOKED/CONFIRMED và DTO.
- [BookingEligibilityValidator](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingEligibilityValidator.java): pure validation membership DATE, duration, notice/advance/count từ policy.
- [BookingConflictException](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/exception/BookingConflictException.java): mã business ổn định.

Production files sửa: [ApiExceptionHandler](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/exception/ApiExceptionHandler.java); [AvailabilitySlotRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/AvailabilitySlotRepository.java), [BookingRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingRepository.java), [MemberRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MemberRepository.java), [MembershipRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MembershipRepository.java), [PersonalTrainerRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/PersonalTrainerRepository.java), [UserRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/UserRepository.java) thêm lock/scalar/query; [BookingPolicyService](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyService.java) chia sẻ cùng query R01 qua getEffectivePolicyAt(now), GET cũ vẫn dùng Clock.

Tests: [validator unit mới](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingEligibilityValidatorTest.java), [HTTP harness](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) thêm nested BookingCreateCases. Không sửa entity, POM, dependency, application properties, runner, fixture Task A/R02 hoặc migrations V1–V6.

Tài liệu sửa: [API](../05_API_DOCUMENTATION.md), [testing](../06_TESTING_GUIDE.md), [business blockers](../07_BUSINESS_RULES_AND_BLOCKERS.md), [roadmap](../08_DEVELOPMENT_ROADMAP.md), [next tasks](../13_NEXT_DEVELOPER_TASKS.md), [harness](../14_HTTP_BASELINE.md), [OpenAPI](../api/openapi.yaml), [trạng thái D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md). Hai tài liệu mới là [quyết định/traceability R03](../decisions/2026-11-20_R03_BOOKING_CREATE.md) và báo cáo này.

## Môi trường và tests thực chạy

Temurin JDK 21.0.13+9, Maven Wrapper 3.10.0, JVM UTC. PostgreSQL 17.12; Docker desktop-linux local engine `npipe:////./pipe/dockerDesktopLinuxEngine`. Container `fitcenter-baseline-20261120-db`, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, task label baseline-20261120, named volume `fitcenter_baseline_20261120_data`, `127.0.0.1:15437` → 5432. DB duy nhất `fitcenter_baseline_20261120_test`, role `fitcenter_baseline_app`, không superuser/createdb/createrole/replication/bypassrls. Container/mount/port/role/history V1–V6 xác minh trước Spring/Flyway; dùng nguyên runner đã guard. Password role test/JWT sinh ngẫu nhiên trong process memory, không in hoặc lưu giá trị thật; không đổi Java/default environment máy.

| Lượt | Passed | Failed | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| Unit focused: validator + R01 policy | 25 | 0 | 0 | 0 | 2026-11-20 11:04:20 |
| HTTP focused | 198 | 0 | 0 | 0 | 2026-11-20 11:09:40 |
| Full trước review isolation | 437 | 0 | 0 | 0 | 2026-11-20 11:10:48 |
| **Full cuối sau khai báo READ_COMMITTED** | **437** | **0** | **0** | **0** | **2026-11-20 11:12:30** |

Không có backend test failure trong các lượt R03 này, không có failure cần sửa hoặc skipped. Sau lượt full đầu, review khai báo rõ isolation và bỏ helper test không dùng; vì có thay source nên chạy lại full. Không coi kết quả trước thay đổi source là bằng chứng duy nhất cho working tree cuối. Docs hoàn thiện sau test, không đổi executable source sau full cuối.

25 unit focused gồm 22 mới và 3 policy regression có sẵn. HTTP 198 gồm 142 R02 + 56 mới. Full **437 = 359 R02 + 22 unit mới + 56 HTTP mới**; focused/full là các tập con/lượt lặp, không cộng dồn. Surefire có 18 XML suites; HTTP một XML chứa 198 testcase. Console có thể ghi aggregate ở nested class và outer class 0, không cộng thêm nested/outer và không gọi 198 là số HTTP requests. Các class legacy tên DatabaseAlignmentTest chạy default profile với V1–V6, không dùng profile alignment.

Các nhóm đã kiểm:

- Happy path 201: UUID/owner/PT/slot/time đúng, CONFIRMED, null cancellation/completion, row DB và slot BOOKED; GET Member/PT thấy booking, Member khác không nhận lịch của owner, available list loại slot. Client gửi memberId người khác/status khác không thay owner/state. Đặt lại slot nhận ERR_SLOT_NO_LONGER_AVAILABLE.
- Role ADMIN/PT 403, thiếu token 401, MEMBER bị SUSPENDED/DISABLED với token đã phát hành 401, ACTIVE Member thiếu profile 404, PT SUSPENDED/DISABLED 404. Thiếu/null/UUID chữ sai 400; missing/mismatched ptId-slotId 404. BOOKED/DISABLED 409; slot legacy 60 phút 409.
- Membership stored inactive/PENDING_ACTIVATION/SUSPENDED/EXPIRED/CANCELLED, không có hiện hành, chưa bắt đầu, đã hết hạn hoặc không phủ session bị từ chối và không đổi slot. Activation midnight Việt Nam; session end trước/bằng/sau midnight sau expiry ở độ chính xác microsecond. Unit kiểm thêm boundary nanosecond và session start coverage.
- Policy absent/inactive/future 404, effective_from bằng now được dùng ở happy path; notice và advance trước/bằng/sau mốc, 14×24 giờ, policy tùy chỉnh không dùng constant. 4 lịch cho thêm một, 5 bị chặn; CANCELLED/COMPLETED/CONFIRMED đã bắt đầu không tính future. Unit kiểm notice=0/start bằng now, past vẫn reject.
- Overlap Member qua PT khác, overlap PT kể cả nguồn slot DISABLED không nhất quán nhưng hợp schema, tiếp giáp Member/PT thành công.
- Hai Member/một slot: đúng một 201 và một 409 ERR_SLOT_NO_LONGER_AVAILABLE; DB đúng một booking. Cùng Member/các slot khác PT khi có 4 lịch: đúng một booking mới và một ERR_MAX_FUTURE_BOOKINGS. Cùng Member/hai slot chồng nhau: đúng một booking và một ERR_BOOKING_OVERLAP.
- Booking/PATCH và booking/DELETE: cả booking thắng lẫn availability thắng. Giữ PT row lock bên ngoài, quan sát hai HTTP requests cùng chờ Lock trước nhả; thứ tự enqueue kiểm soát bằng quan sát khóa, không sleep giả đồng bộ. Booking thắng giữ time gốc/BOOKED/CONFIRMED và chặn PATCH/DELETE; PATCH/DELETE thắng thì booking 409, không có booking trỏ thời gian/trạng thái sai. PATCH cùng ID được chặn bằng version đã đọc trước chờ.
- Rollback thật bằng exclusion: SQL connection INSERT booking Member-overlap chưa commit trên PT khác. HTTP không thấy row chưa commit ở validation, flush BOOKED rồi INSERT bị chặn tại constraint. Commit SQL competitor làm HTTP 409 ERR_CONFLICT; transaction rollback, slot target AVAILABLE và không có booking target. Không thêm trigger/migration hoặc endpoint test để ép lỗi.

Các assertions kiểm status/error code/envelope/correlation, payload fields, DB rows/counts/time và ownership, không chỉ HTTP 200. UUID tạo qua HTTP/SQL được ghi registry và cleanup chính xác theo FK trong transaction. Membership ngày/status và account status chỉ sửa fixture, được khôi phục sau từng scenario. Không truncate/xóa theo Member/PT/range.

OpenAPI YAML/structure và **101 local references, 16 paths** đạt với SnakeYAML 2.6 cached/JDK 21; kiểm POST booking only, input đúng hai UUID, auth/response/error contract, policy GET-only và availability giữ ba write methods. Không tuyên bố đã chạy OAS validator chuyên dụng. Whitespace, relative links, source hashes và phạm vi được review riêng.

Hậu kiểm users/members/trainers/plans/memberships/slots/bookings/policy/notifications đều 0 dòng như trước test. History đúng 1–6, tất cả success; không V7, clean/repair, alignment hoặc onboarding BLOCKED. DB test được dừng sau nghiệm thu, giữ named volume; không đụng tài nguyên dùng chung.

## Chạy lại và giới hạn

Theo [testing guide](../06_TESTING_GUIDE.md) và [runner guide](../14_HTTP_BASELINE.md), kiểm tra đúng JDK 21, container ID/label/volume/loopback port/DB role. Cấp credentials role test riêng qua secure prompt hoặc process environment, không đưa mật khẩu thật vào command line/Git. Nếu dùng role có credentials ngẫu nhiên từ lượt này, cần cấp lại password qua quyền quản trị **test riêng đã xác minh** trước khi chạy; giá trị cũ không được giữ trong repo/báo cáo.

```powershell
# Từ backend, unit không cần DB:
.\mvnw.cmd -B -ntp '-Dtest=BookingEligibilityValidatorTest,BookingPolicyServiceTest' test

# Từ repository root, HTTP focused và full:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase -FullSuite
```

ExecutionPolicy Bypass chỉ child process; không đổi policy máy. booking_policy ban đầu phải trống cho scenarios; có dữ liệu thì guard dừng, không tự xóa. Không dùng DB dùng chung, onboarding scripts hoặc profile alignment. Surefire bị ghi đè qua các lượt; đọc source hashes và kết quả theo working tree tương ứng.

Payload chỉ có IDs; version guard bảo vệ thay đổi trong lúc request chờ, không phát hiện UI stale trước lần đọc đầu tiên. Future booking/cancel/complete/membership writers phải giữ giao thức khóa và recheck; raw SQL bỏ khóa vẫn có thể vượt count hoặc tạo trạng thái chéo không được V4 cấm. Không tuyên bố kiểm thử mọi writer ngoài ứng dụng hoặc mọi lịch xử lý concurrency. Chưa load/performance benchmark hoặc E2E toàn hệ thống.

D01 phần eligibility lúc đặt đã có, recheck trước bắt đầu dịch vụ chưa có. D02/D03 notice/advance/count và D06 duration/UTC đã áp cho create. D04 booking reject thiếu policy đã có; không default. D05 policy PUT, cancel deadline, D07 cancel/complete/completedAt và membership write chưa triển khai; scheduling/versioning tiếp tục hoãn. Không thêm PENDING/REJECTED, Redis/dependency hoặc migration. Không có blocker schema cho R03 đã giao.

## Source working tree cuối đã test

SHA256 dưới đây là bytes executable sources của lượt full cuối 437, trước thay đổi LF/CRLF nếu stage sau này. Docs không thay executable source.

| File | SHA256 |
|---|---|
| ApiExceptionHandler.java | `F1B1C88FDA939F0B63CB42E8E57B962A84082A237FF729CE95633BE59F7EAE9A` |
| AvailabilitySlotRepository.java | `576ABFF460BA4A7E8B70CE3E582A5342CE691E64C25E09DF767A92D14ED2C44C` |
| BookingRepository.java | `0EF3A40C2E3B9E060E36B6A740EB4C57D173E28544A751581E99CB0EF2D7DF00` |
| MemberRepository.java | `10298D9954405B7E051CDC24D88011F1D9027C3813DC2265E28AA9081BEEE011` |
| MembershipRepository.java | `3B7E5E3CBA2B8CB4FC418A8C6BBA25827CF35ACD023A66AA9C4D19C68ADB22AE` |
| PersonalTrainerRepository.java | `FF0645DE3BC43C9C783A8687FC79C78E12234E8BD6CA5FD5F09F9025253BCC7B` |
| UserRepository.java | `A6DDADBADD6079AECC5F52E88258D19264BA8DCF432E9FE359B34A38F94A1642` |
| BookingPolicyService.java | `FFB70EAB4E2EDB41051FB94950E380CF188A709D600D2DA0ECC20E5F2E1BC80F` |
| HttpBaselineTest.java | `52BD994B83A1CC73B98BBE59B8CE7A29F36FC438F2957558AFB94B15ACA2EED1` |
| BookingCreateController.java | `00BDE011463EE08CC3356148A5597774FEF51CE2D8485654478688714687ADBC` |
| BookingCreateRequest.java | `6AFC621C282A2A70E7F0B7FE78863714EE9DF1CE4852FCCF395E54FBF9994FDC` |
| BookingConflictException.java | `0788D6738E20EEAFFB3FF6E908CC47D0C4E9A742CE38AAD55213CCAE70E12844` |
| BookingCreateService.java | `1B43E9BC040CC24FB8162204CC5DE625140F5D16AC13A15D4A36CA4781E556E8` |
| BookingEligibilityValidator.java | `2EFD1E0FDFA05D9B96D7DC05AE0548A424FD7C76740116BA5654DB69295F26C9` |
| BookingEligibilityValidatorTest.java | `7BF20124764513AC8F3F5EAE5C63E017728F86481DD7A9E24BA92F795363D417` |
