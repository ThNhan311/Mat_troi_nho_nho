# D01 A — kết quả Backend service eligibility

Ngày thực hiện 20/11/2026. GET `/api/v1/pt/bookings/{id}/service-eligibility` đã triển khai và kiểm thử theo phương án A người dùng chốt. Chỉ kiểm tra hiện tại, không lưu bắt đầu hoặc đổi completion. D01 có API phía Backend; Frontend chưa tích hợp nên chưa hoàn tất luồng chặn dịch vụ end-to-end. Đây là unit/HTTP/PostgreSQL integration, không phải E2E toàn hệ thống.

## Git và nguồn

Base commit local `63fe3945715888c7cbc9ad436c65d0e7f16273de`, nhánh feature/backend-booking-policy-write có tracked working tree sạch lúc tiếp tục. Chỉ có untracked Face ngoài task, giữ nguyên. Kiểm tra feature/backend-service-eligibility chưa tồn tại rồi tạo từ đúng base; HEAD vẫn `63fe394`, D01 chưa stage/commit. Không reset/stash/push/merge. Không tìm thấy AGENTS.md ở các ancestors/cây backend/docs đã kiểm tra trong phiên tiếp nhận.

Nguồn: task người dùng chốt A/cửa sổ/account/response; Topic11 AC-BKG-07/TC-BKG-06 đã đọc OOXML khi khảo sát, SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`; [D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md), V1/V2/V4, code R03 membership validation, R04 lifecycle và policy snapshot hiện có. Không suy ra trang hoặc copy bản Topic11 ngoài repo vào Git. [Quyết định/contract](../decisions/2026-11-20_SERVICE_ELIGIBILITY.md) được ghi/báo trước coding, phân biệt quy tắc người dùng bổ sung với nguồn.

## Triển khai và diff

PT ACTIVE sở hữu booking, identity từ principal/profile, không dùng client memberId/ptId. Auth/role/ownership theo 401/403/404 hiện có; UUID sai 400. PT được phép nhận 200 kể cả false; đúng ba fields eligible,checkedAt,reasonCodes, không membership/profile/account details hoặc PII. checkedAt lấy một lần từ server Clock/UTC, Cache-Control no-store, không backend cache.

Lý do theo thứ tự: BOOKING_NOT_CONFIRMED; SESSION_NOT_STARTED (now<start); SESSION_ENDED (now>=end); MEMBER_ACCOUNT_INACTIVE; MEMBERSHIP_INACTIVE; MEMBERSHIP_NOT_COVERED. eligible=true chỉ khi mảng rỗng; lý do độc lập được thu thập đầy đủ. Nhóm membership dùng đúng pure validation R03: hiện hành chưa CANCELLED, stored ACTIVE/hiệu lực ngày Việt Nam, start_date từ 00:00 Asia/Ho_Chi_Minh và expiry_date inclusive, bao phủ cả session `[start,end)`. Coverage chỉ đánh giá khi membership hợp lệ hiện tại. Không áp policy notice/advance/count/cancellation hoặc đòi policy tồn tại. Không tự ghi lại trạng thái membership khi đã hết hạn.

readOnly=true, REPEATABLE_READ, timeout 10 giây. SELECT actor đầu thiết lập PostgreSQL MVCC snapshot, Clock trong transaction, những reads tiếp theo (PT profile, booking, Member/account, membership) cùng snapshot. Query membership mới không @Lock; không dùng query PESSIMISTIC_READ của R03, SELECT FOR UPDATE hoặc policy advisory lock. Không thêm chiều khóa hàng với writers hiện tại. Kết quả là đánh giá tại checkedAt trên snapshot đọc, không phải quyền sử dụng lâu dài/bảo đảm dữ liệu không đổi sau response; writer có thể commit trong khi GET chạy, GET mới đọc snapshot mới.

17 file thuộc task: 5 production, 2 tests, 10 docs/OpenAPI.

- Production mới: [ServiceEligibilityController](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/ServiceEligibilityController.java), [response/reason enum](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/ServiceEligibilityResponse.java), [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityService.java), [validator](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityValidator.java). Sửa [MembershipRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MembershipRepository.java) thêm query không khóa, giữ nguyên query khóa R03.
- Tests: [validator unit mới](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityValidatorTest.java), [HTTP harness](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) thêm ServiceEligibilityCases và test-only Clock gate cho transaction RR. Không hook/endpoint test trong production.
- Docs: sửa [API](../05_API_DOCUMENTATION.md), [testing](../06_TESTING_GUIDE.md), [blockers](../07_BUSINESS_RULES_AND_BLOCKERS.md), [roadmap](../08_DEVELOPMENT_ROADMAP.md), [next tasks](../13_NEXT_DEVELOPER_TASKS.md), [harness](../14_HTTP_BASELINE.md), [OpenAPI](../api/openapi.yaml), [D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md); mới [quyết định/traceability](../decisions/2026-11-20_SERVICE_ELIGIBILITY.md) và báo cáo này.

Không sửa entity/schema/V1–V6, không V7/migration, startedAt/startedBy hoặc IN_PROGRESS; không triển khai B, Membership/Payment/Face, frontend, dependency mới hoặc sửa R04 lifecycle. Không thay GET policy, create/cancel semantics, application config, runner hoặc fixture class hiện có.

## Môi trường và tests thực chạy

Temurin JDK21.0.13+9, Maven Wrapper 3.10.0, JVM UTC; PostgreSQL17.12 trên local Docker desktop-linux engine `npipe:////./pipe/dockerDesktopLinuxEngine`. Container fitcenter-baseline-20261120-db, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, label fitcenter.task=baseline-20261120, volume fitcenter_baseline_20261120_data, loopback127.0.0.1:15437→5432. DB duy nhất fitcenter_baseline_20261120_test, app role fitcenter_baseline_app không superuser/createdb/createrole/replication/bypassrls. Engine/container/mount/port/readiness/DB/role/history V1–V6 đã xác minh trước Spring/Flyway bằng preflight và runner guard hiện có. Không alignment/onboarding BLOCKED/clean/repair. Credentials/JWT ngẫu nhiên trong process memory, không in/lưu giá trị thật, không đổi Java mặc định máy.

| Lượt thực chạy | Passed | Failed | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| Unit D01 + R03 membership focused đầu | 33 | 0 | 0 | 0 | 2026-11-20 16:20:44 |
| HTTP/DB focused đầu, một fixture role vi phạm FK V1 | 388 | 0 | 1 | 0 | 2026-11-20 16:21:41 |
| **Unit focused cuối** | **34** | **0** | **0** | **0** | **2026-11-20 16:22:55** |
| **HTTP/DB focused cuối** | **388** | **0** | **0** | **0** | **2026-11-20 16:23:35** |
| **Full regression source cuối** | **668** | **0** | **0** | **0** | **2026-11-20 16:25:55** |

Lỗi đã sửa: test đầu thử UPDATE role MEMBER→PT trên User đang có Member, nhưng V1 fk_members_user (user_id,user_role)→users(id,role) chặn SQLSTATE23503 trước GET. Không sửa schema để tạo dữ liệu sai; bỏ invocation HTTP không thể có dưới FK hợp lệ, thêm unit cho nhánh phòng vệ role. Hai status SUSPENDED/DISABLED vẫn kiểm qua HTTP. Ca role lỗi không được gọi đã đạt API hoặc skipped; unit mới và focused/full cuối chạy lại đạt. Không có failure/error còn mở; JUnit skipped cuối=0.

Full **668 = 618 policy-write baseline + 12 unit D01 mới + 38 HTTP/DB D01 mới**. Unit focused34 gồm22 R03 cũ+12 mới; focused388 gồm350 cũ+38 mới. Các focused/lượt sửa là tập con/lặp, không cộng dồn vào full. Surefire21 XML suites; HttpBaselineTest một XML388 testcase, không gọi388 là số HTTP requests. Console nested209 gồm142 legacy+67 policy write, D01 38, create56, lifecycle85, outer0; không cộng nested/outer hai lần. DatabaseAlignmentTest tên legacy chạy default V1–V6, không dùng alignment profile. Kết quả618 của task trước là lịch sử, không coi là D01 vừa chạy.

Nhóm thực kiểm:

- Owner PT GET200 true, đúng ba fields/UTC/no-store/no PII, không policy vẫn hoạt động. Query memberId/ptId khác không thay owner; PT khác kể cả query ptId giả không bypass404; missing UUID404, UUID sai400, ADMIN/MEMBER403, anonymous/PT SUSPENDED/DISABLED token cũ401.
- CONFIRMED/CANCELLED/COMPLETED với false200 và metadata bất biến; trước/bằng/sau start, ngay trước/bằng/sau end ở HTTP microsecond và unit nanosecond. Nhiều lý do cùng lúc đúng thứ tự/không trùng/eligible iff empty.
- Member account SUSPENDED/DISABLED; membership thực sự thiếu (DELETE fixture đúng UUID rồi restore), PENDING_ACTIVATION/SUSPENDED/EXPIRED/CANCELLED, stored ACTIVE chưa bắt đầu/hết hạn. Không viết lại trạng thái khi đọc.
- DATE Việt Nam: kích hoạt trước/bằng midnight, expiry bao gồm hết ngày; session end trước/bằng/sau midnight ngày sau expiry, thiếu coverage cả đầu hoặc cuối session. Không dùng UTC midnight sai. Membership khôi phục ACTIVE thì GET mới true, checkedAt mới, không cache.
- Full DB snapshots booking/slot/membership/account/policy trước/sau GET không đổi, kể cả false hoặc policy rất hạn chế. No/restrictive policy không áp lại booking notice/advance/count/cancellation.
- Concurrency có đồng bộ thật: Clock gate test-only nhận đúng read-only RR sau first SELECT, dừng trước các reads còn lại. Writer SQL commit account+membership SUSPENDED, hoặc R04 Member cancel HTTP commit (policy deadline0 tại start, slot DISABLED), rồi release GET. GET vẫn đọc trọn snapshot cũ, không mixed-state, không undo writer; GET mới nhận lý do mới. Read không khóa hàng nên writer commit được trong lúc GET còn chạy. Không chỉ gửi request tuần tự giả concurrency, không thêm production hook/schema/trigger.
- Completion khi chưa gọi eligibility và sau GET false vẫn200 COMPLETED theo R04, slot DISABLED/completedAt đúng Clock; không dùng eligibility làm marker hay bắt buộc membership ACTIVE tại completion.

Fixture cleanup/restore theo UUID đã registry, không truncate hoặc xóa theo range/member/PT. Missing membership chỉ xóa đúng fixture.membershipA rồi restore trước fixture close; giữ các giá trị gốc ngoài mutation scenario. Hậu kiểm users/members/trainers/plans/memberships/slots/bookings/policy/notifications đều0 như trước tests, history1–6 success; DB test dừng sau nghiệm thu, giữ volume. Không chạm tài nguyên dùng chung hoặc file Face.

OpenAPI YAML/structure đạt **20 paths, 135 local references** với SnakeYAML2.6 cached/JDK21; kiểm GET-only eligibility/auth/200/400/401/403/404, đúng ba response fields, no-store và sáu reason codes, cùng contract policy/R02/R03/R04 cũ. Không tuyên bố OAS validator chuyên dụng. Docs hoàn thiện sau full, executable source không đổi; scope/whitespace/relative links/credential patterns và hashes được review riêng.

## Chạy lại và giới hạn

Theo [testing guide](../06_TESTING_GUIDE.md) và [runner guide](../14_HTTP_BASELINE.md), dùng JDK21, xác minh đúng container ID/label/volume/port/DB/role trước Spring/Flyway. Cấp password qua secure prompt/process environment; không hardcode hoặc đưa giá trị thật lên command line/Git. Credentials ngẫu nhiên cũ không được lưu; khi cần, cấp lại bằng quyền quản trị đúng test DB đã xác minh. Chỉ đổi JAVA_HOME/PATH của process.

```powershell
# Từ backend/JDK21, không cần DB:
.\mvnw.cmd -B -ntp '-Dtest=ServiceEligibilityValidatorTest,BookingEligibilityValidatorTest' test

# Từ repository root, HTTP/DB focused rồi full khi cần:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase -FullSuite
```

Bypass chỉ child process, không đổi execution policy máy. Runner dừng DB nếu tự khởi động; nếu DB chạy từ chuẩn bị thì dừng đúng resource sau test, giữ volume. Không có blocker schema/decision trong phạm vi A đã chốt. Kết quả checkedAt/snapshot có thể cũ khi dữ liệu đổi sau đó; Frontend cần gọi/refresh đúng lúc và tuân thủ kết quả. Chưa có Frontend tích hợp hoặc kiểm thử chặn dịch vụ end-to-end, không lưu/thi hành quyền bắt đầu lâu dài, không start marker hoặc gate mới cho complete. Không benchmark/frontend/Face/payment tests. D01 Backend API đã có, phương án B không được triển khai. Task giữ chưa stage/commit cho review.

## SHA256 executable source đã full-test

Base commit `63fe3945715888c7cbc9ad436c65d0e7f16273de` + 7 file dưới đây. Docs/OpenAPI hoàn thiện sau full, không đổi executable source.

| File | SHA256 |
|---|---|
| backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MembershipRepository.java | 1338EE23A4C1E02592F8396A1EB43BCA1F2B2869D0DB5E571C4D7AC318B89928 |
| backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java | 6E4F3A7287B89214C637D945CB5D42102D472984C1B531F8067B2015EAF3E903 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/controller/ServiceEligibilityController.java | FE0EEEDFB714A6CA6BF6B2D7BA25240DBA7ED8F92832A695E14FD755951BDDEC |
| backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/ServiceEligibilityResponse.java | F0DACC890031E21993CB53B3ECD1B04938DC8C54AD650264579D1DDBE96CC1ED |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityService.java | EAA18D7035E0C91DED6FD6757D9A810DC0A1B079AC4AF9C3C39E4DFC03153239 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityValidator.java | 1C232E6FAD248E568ADB2325C70CD93AD096CBF5B28AA5544ED22DF6FE4DA709 |
| backend/src/test/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityValidatorTest.java | 58D8AFE52E29A9A1AAA52CED0E98704806CD2401E82765CA1576D3DDE5985FFF |
