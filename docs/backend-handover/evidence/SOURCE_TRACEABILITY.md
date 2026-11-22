# Truy vết source và phạm vi kiểm tra

Snapshot local `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`; trạng thái dưới đây là mức đọc/đối chiếu cho từng nhóm, không khẳng định audit đầy đủ từng dòng. Các đường dẫn source tương đối với repository.

| Tài liệu / nhận định | Source và migration | Test / commit | Mức xác minh |
|---|---|---|---|
| 01/05 API và role | `backend/src/main/java/vn/edu/tdtu/fitcenter/controller/`, `config/SecurityConfig.java` | ControllerTest; `76c17a4`, `07f006c`, `0ae542a` | Đọc controller và security; contract chi tiết chưa hoàn tất |
| 02 JWT, danh tính | `security/JwtAuthenticationFilter.java`, `security/JwtService.java`, `service/BookingQueryService.java`, V1/V4 | JwtServiceTest, JwtAuthenticationFilterTest, BookingControllerTest | Đã đối chiếu luồng chính |
| 04 ràng buộc | `database/migrations/V1__core_users_members.sql` đến `V6__audit_log.sql` | `DatabaseAlignmentTest`; [Task 04](TASK04_TEST_SUMMARY.md) | Đọc V1–V6; runtime là lịch sử |
| 04 V7 | `git show fix/database-canonical-layout:database/database/migrations/V7__membership_periods.sql` | branch `558fb03` | Đọc nội dung qua Git; chưa chạy hoặc xác minh dữ liệu |
| 05 DTO | `backend/src/main/java/vn/edu/tdtu/fitcenter/dto/` | Các controller tests | Đã đọc DTO; nullability thực tế cần bổ sung |
| 06 test | `backend/src/test/java/vn/edu/tdtu/fitcenter/` | [Task 04](TASK04_TEST_SUMMARY.md) | Đã kiểm kê và đọc tên/trường hợp; chưa đọc mọi assertion |
| 03 cấu hình | `backend/pom.xml`, `backend/src/main/resources/application*.properties`, `backend/scripts/start-local.ps1` | Task 04 | Đã đọc các phần liên quan; chưa chạy setup |
| 07 nghiệp vụ | Schema comments và source | Chưa xác định SRS/UC/BR chính thức trong checkout | BLOCKED, cần nguồn chính thức |

Chưa đọc đầy đủ từng assertion của tất cả test, toàn bộ seed `demo_data_clean.sql`/`demo_data_review.sql` và mọi dòng báo cáo lịch sử Task 01–04; không sử dụng các seed đó. Không có bằng chứng đã khảo sát đầy đủ SRS/UC/BR, data dictionary hoặc ERD chính thức. Chưa xác nhận nội dung tài liệu trong các worktree khác ngoài V7 qua Git. Không đọc các log có thể chứa credentials.

## M-01 — Admin plan create (baseline 1b1e323)

| Yêu cầu | Source thực tế | Evidence |
|---|---|---|
| Topic11 UC-21/§4.1, V2: ngày, giá>=0, không unique name | [request](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/membership/MembershipPlanCreateRequest.java), [schema V2](../../../database/migrations/V2__membership_payment.sql) | HTTP strict types/range/scale/Unicode/giá0/duplicate names |
| ADMIN ACTIVE, server UUID/ACTIVE, transaction | [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/AdminMembershipPlanController.java), [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/MembershipPlanCreateService.java) | [service unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/MembershipPlanCreateServiceTest.java), [HTTP+PG](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) MembershipPlanCreateCases |
| List ACTIVE và create trên giao diện gốc | [Admin screen](../../../frontend/fitcenter_ad/lib/screens/membership_page.dart), [client](../../../frontend/fitcenter_ad/lib/services/membership_plan_service.dart) | [widget/client](../../../frontend/fitcenter_ad/test/membership_plan_test.dart), Chrome thật và DB [M-01](M01_PLAN_CREATE.md) |
| Session/no replay/exact UUID cleanup | ApiClient giữ nguyên; navigator epoch, modal phiên; [UI runner](../../../frontend/verify-membership-plan-ui.mjs), [DB guard/audit](../../../frontend/verify-membership-plan-demo.mjs) | Log/manifest ngoài Git; hashes/evidence cuối, không gọi Member GET là Member UI |

[Quyết định đã giao M-01](../decisions/2026-11-22_M01_PLAN_CREATE.md). Bốn tài liệu research giữ nguyên snapshot khảo sát; không tự áp các proposal Membership/Payment/V7 còn mở.

## Admin account/PT activation22/11

| Yêu cầu | Source | Evidence/giới hạn |
|---|---|---|
| Admin tạo inactive User+profile nguyên tử | [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/AdminAccountService.java), [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/AdminAccountController.java) | [HTTP/PG](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/AccountHttpTest.java): role/validation/FK/audit/rollback/race duplicate/noJWT |
| OTP5phút/one-use/grant/password | [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/activation/PtActivationService.java), [JDBC](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/activation/JdbcActivationStore.java) | [unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/activation/PtActivationServiceTest.java), SMTP loopback; schema candidate chưa áp, chưa HTTP/PG activation race |
| Original Admin/PT UI, session/no-replay | [Admin](../../../frontend/fitcenter_ad/lib/screens/account_page.dart), [PT](../../../frontend/fitcenter_pt/lib/screens/pt_activation_page.dart) | [báo cáo](ACCOUNT_PT_ACTIVATION.md), client/widget + Chrome/DB account; PT UI thật chỉ gate503 |

[Quyết định/candidate](../decisions/2026-11-22_ACCOUNT_PT_ACTIVATION.md). Source hashes gắn working tree, không cộng focused vào full, không tuyên bố E2E toàn FitCenter.

## PT activation rehearsal PostgreSQL —22/11

| Yêu cầu | Source | Evidence |
|---|---|---|
| V8 riêng, không V7/canonical mutation | [SQL](../../../database/activation-rehearsal/V8__pt_account_activation.sql), [pre-Flyway guard](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/activation/ActivationRehearsalConfiguration.java) | [schema10tests](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/ActivationSchemaRehearsalTest.java), [báo cáo](PT_ACTIVATION_POSTGRES.md) |
| OTP/grant/password atomic và concurrent | [HTTP20tests](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/PtActivationPostgresTest.java), [SMTP sink](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/ActivationLoopbackMailSink.java) | Full801, focused65 là tập con; Clock sau lock, PostgreSQL wait_event thật, rollback |
| UI gốc email→OTP→password→ACTIVE→login | [UI runner](../../../frontend/verify-pt-activation-e2e.mjs), [mail sink](../../../frontend/activation-mail-sink.mjs), [DBaudit/cleanup](../../../frontend/verify-activation-rehearsal-db.mjs) |13UI/4HTTP/DBaudit4, source hashes và ảnh trong báo cáo; không production email |
