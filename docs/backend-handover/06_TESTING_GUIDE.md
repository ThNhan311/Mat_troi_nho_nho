# Kiểm thử

Cập nhật D01 phương án A: base policy write `63fe394`, working tree thêm ServiceEligibilityCases và unit mới, xem [contract](decisions/2026-11-20_SERVICE_ELIGIBILITY.md), [evidence](evidence/SERVICE_ELIGIBILITY.md). D01 có API kiểm tra phía Backend; chưa tích hợp Frontend/end-to-end. Không ghi dấu bắt đầu, không đổi R04 complete.

Unit từ backend/JDK21: `.\mvnw.cmd -B -ntp '-Dtest=ServiceEligibilityValidatorTest,BookingEligibilityValidatorTest' test`. HTTP/DB focused/full dùng guarded runner hiện có. Assertions gồm đúng ba response fields/no PII, reason ordering, checkedAt UTC/no-store, full snapshots trước/sau GET, DATE Việt Nam, hồi phục membership, completion không phụ thuộc GET. Không sửa production Clock để test: test-only Clock gate chỉ dừng transaction read-only REPEATABLE_READ sau SELECT đầu, cho SQL writer commit account/membership hoặc R04 HTTP cancel commit giữa các reads, rồi xác minh snapshot cũ/lần GET mới. Đây là tranh chấp thật được đồng bộ bằng latch, không request tuần tự giả concurrency. Fixture restore theo UUID; không truncate hoặc mutation ngoài fixture. Kết quả thật, lỗi fixture đã sửa và hashes ở evidence; focused là tập con, không cộng dồn.

Cập nhật Policy write: R04 đã đóng local `8cb95e2`; working tree mở rộng BookingPolicyWriteCases cho PUT/GET, hai Admin độc lập và policy snapshot R03/R04. [Báo cáo](evidence/BOOKING_POLICY_WRITE.md) ghi kết quả thực, failure fixture đã sửa, source hashes và giới hạn; các số R04 phía dưới là lịch sử, không tính thành test PUT đã chạy.

Unit focused từ backend/JDK 21: `.\mvnw.cmd -B -ntp '-Dtest=BookingPolicyServiceTest,BookingPolicyWriteServiceTest' test`. HTTP/DB focused và full dùng nguyên guarded runner ở hướng dẫn dưới; không thêm profile/dependency. Policy IDs tạo qua PUT/SQL được registry cleanup đúng UUID; Admin thứ hai có email example.invalid/password ngẫu nhiên/BCrypt ứng dụng và được xóa đúng UUID sau test. Không truncate/xóa theo khoảng hoặc dữ liệu ngoài fixture.

Hai PUT giữ exclusive advisory lock `(20261120,22)` bên ngoài, quan sát hai HTTP requests cùng chờ trước release; kiểm empty/existing và đảo hai Admin. Reader/booking create/cancel chờ PUT giữ transaction chưa commit, dùng latch và quan sát DB Lock; sau commit lấy Clock/policy mới. Kiểm rollback cả first-insert và in-place update bằng service thật trong PostgreSQL outer transaction, đọc thấy SQL đã ghi trong transaction rồi rollback; HTTP GET chờ và thấy cấu hình cũ/404 sau rollback. Đây là HTTP/DB integration, không gọi toàn bộ ca rollback là HTTP writer failure. Focused là tập con của full, không cộng dồn. D01 service-start check vẫn chưa triển khai.

Cập nhật R04: R03 đã commit local `394a21f` sau review 25 file/15 source hashes và evidence 437 tests; không chạy lại full chỉ để commit khi code không đổi. R04 có Member cancel, PT cancel và PT complete. Người dùng chốt PT cancel chỉ trước startAt; xem [contract R04](decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md) và [evidence R04](evidence/R04_BOOKING_LIFECYCLE.md). D01 service-start check vẫn chưa có.

Unit R04 từ backend với JDK 21: `.\mvnw.cmd -B -ntp '-Dtest=BookingLifecycleValidatorTest' test`. HTTP focused/full dùng nguyên runner đã guard và lệnh trong phần R03/R02 dưới đây; không thêm profile/dependency/test endpoint. Nhóm BookingLifecycleCases dùng Clock, UUID riêng cho booking/slot/policy và khôi phục mutation fixture sau từng ca.

Concurrency giữ row lock PT trên JDBC connection riêng, quan sát một rồi hai request cùng chờ Lock trong pg_stat_activity trước nhả. Khi cùng Member, request thứ hai có thể chờ Member lock; đây vẫn là tranh chấp thật, không request tuần tự. Kiểm cancel/cancel, complete/complete, Member cancel/complete, cancel/rebook và từng lifecycle với PATCH/DELETE ở cả hai thứ tự. Rollback dùng slot DISABLED có CONFIRMED và một slot AVAILABLE overlap (hợp V4 nhưng cố ý không nhất quán nghiệp vụ): booking CANCELLED được flush trước, slot mở lại đụng exclusion, yêu cầu 409 và rollback đúng toàn bộ snapshot. Không sửa schema/trigger để ép lỗi.

PT cancel HTTP kiểm trước/bằng/sau startAt, request đến trước nhưng chờ khóa qua startAt, account bị suspend trong lúc chờ, reason/role/ownership/terminal metadata và slot DISABLED không rebook được. Tranh chấp PT/PT, PT/Member cancel, PT/complete, PT cancel/create, request PT cũ/rebook và PT cancel/PATCH/DELETE đều giữ khóa ngoài và quan sát requests đang chờ trước release. Rollback PT cancel gọi service thật trong transaction PostgreSQL, kiểm cả hai rows đã flush rồi chủ động abort transaction và so snapshot sau rollback; đây là DB integration, không giả là HTTP failure. Kết quả trước khi PT cancel được triển khai vẫn là lịch sử, không dùng để tuyên bố API này đã đạt. Số kết quả mới và source hashes trong evidence R04; focused là tập con, không cộng dồn.

Không chạy test trong lượt sửa tài liệu. [Task 04](evidence/TASK04_TEST_SUMMARY.md) báo cáo ngày 08/11/2026 tại HEAD `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`: full Maven/JUnit 214 pass, 0 fail/error/skipped; focused Maven 9 pass, không cộng vào full; 90 kiểm tra HTTP ba API, 9 login và 17 kiểm tra SQL pass là các nhóm kiểm tra riêng, không cộng vào số test Maven. Runtime JDK 21.0.11, PostgreSQL 17.11 riêng, Flyway V1–V6, Hibernate validate. Đây là kết quả lịch sử của môi trường báo cáo, không xác nhận môi trường hiện tại.

Riêng quan sát SQLSTATE 23505 của unique index bị SKIPPED vì exclusion constraint chặn trước bằng 23P01; metadata index và việc chặn trùng được báo cáo xác minh, không coi 23505 đã quan sát. HTTP thực dùng fixture tổng hợp, không chứng minh mọi module. BookingRepositoryQueryTest kiểm tra định nghĩa query, không tự chứng minh SQL integration. Unit/Mockito và MockMvc có sẵn dưới [test](../../backend/src/test/).

Trên máy mới trong `backend`, chạy `.\mvnw.cmd test`; mặc định test DB/context có điều kiện có thể bị skip. Muốn bật, tạo DB test độc lập, xác minh URL và quyền, cấu hình `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, đặt `$env:RUN_DB_TESTS='true'`, `$env:JAVA_TOOL_OPTIONS='-Duser.timezone=UTC'` rồi chạy `.\mvnw.cmd test`. Kiểm tra Surefire XML và số skipped thực tế. Build đề xuất `.\mvnw.cmd package` sau khi xác định target; không xem build là test HTTP.

Harness Task 04 được báo cáo lưu ngoài repository trong thư mục tạm của lần chạy cũ; không tìm thấy tại đường dẫn báo cáo khi audit. Chưa thể tái lập đầy đủ 90 HTTP/17 SQL từ source được xác minh; cần xây dựng fixture/harness mới được duyệt, không sao chép token hoặc credentials. Không chạy thử trên DB bảo vệ.

## Danh mục test và lệnh

`AuthServiceTest`, `MembershipServiceTest`, `AvailabilityServiceTest`, `BookingQueryServiceTest`, `PtBookingQueryServiceTest` kiểm thử service; `BookingControllerTest`, `MembershipControllerTest`, `PersonalTrainerControllerTest`, `PtAvailabilityControllerTest`, `PtBookingControllerTest` kiểm thử MVC; `JwtServiceTest`, `JwtAuthenticationFilterTest` kiểm thử bảo mật; `BookingRepositoryQueryTest` kiểm tra định nghĩa repository; `DatabaseAlignmentTest` và `FitcenterApplicationTests` yêu cầu `RUN_DB_TESTS=true`.

Ví dụ focused: `.\mvnw.cmd '-Dtest=BookingControllerTest' test`; full: `.\mvnw.cmd test`. Đọc `backend/target/surefire-reports/TEST-*.xml`, cộng tests/failures/errors/skipped theo suite, không cộng focused vào full. Chỉ gọi HTTP sau khi server thử và fixture riêng đã được xác minh; xem [API](05_API_DOCUMENTATION.md). Tóm tắt có thể chia sẻ: [Task 04](evidence/TASK04_TEST_SUMMARY.md).

## Smoke test nháp

Automation được hoãn; smoke test nháp bị chặn và không thuộc bộ công bố mặc định, xem [trạng thái](scripts/README.md). Người tiếp nhận làm theo [hướng dẫn thủ công](12_MANUAL_QUICKSTART.md), tự xác nhận kết quả trên môi trường riêng. Các lệnh hướng dẫn chưa được kiểm thử đầu-cuối và không thay thế 90 HTTP checks lịch sử của Task 04.

## Harness Task A và R01

Task A đã đóng bằng commit local 073e131 với 285 tests đạt theo [bằng chứng Task A](evidence/TASK_A_HTTP_BASELINE.md). Không coi đây là số test của working tree R01. Script test-http-baseline.ps1 mới là runner đã kiểm thử, khác các onboarding scripts nháp BLOCKED; xem [cách chạy](14_HTTP_BASELINE.md).

R01 bổ sung BookingPolicyServiceTest với Clock cố định/tiến lên, và các ca HTTP thật trong HttpBaselineTest: ADMIN đọc đúng DTO/giá trị khác bộ ban đầu, MEMBER/PT 403, ẩn danh 401, thiếu/inactive/tương lai 404 BOOKING_POLICY_NOT_FOUND, inactive cũ không fallback cho active tương lai, effective_from bằng now, UTC với dữ liệu offset +07:00, header/body correlation ID và GET không ghi dữ liệu. Clock tùy chỉnh chỉ nằm trong test configuration; production vẫn dùng Clock.systemUTC.

Policy scenarios cần booking_policy trống trên DB test riêng; harness dừng trước seed nếu có dữ liệu, không tự xóa policy có sẵn. Mỗi ca tự tạo UUID policy và cleanup đúng UUID trong finally; 14/2/4/5 chỉ dùng cho fixture. Fixture PT hủy dùng slot DISABLED theo D07; đây không phải triển khai cancel lifecycle.

Unit tests R01 không cần DB, từ backend với JDK 21 đã chọn:

```powershell
.\mvnw.cmd -B -ntp '-Dtest=BookingPolicyServiceTest' test
```

HTTP focused và full regression dùng cùng runner/guard JDK 21 + container/volume/port/role/V1–V6. Chạy từ repository root, thay đường dẫn và container ID đã xác minh; runner hỏi mật khẩu role test nếu chưa cấp qua process environment:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase -FullSuite
```

Không cộng focused vào full. Surefire reports ghi đè theo lượt; kết quả, source hashes và phạm vi chưa triển khai nằm ở [báo cáo R01](evidence/R01_BOOKING_POLICY_READ.md).

## Regression R02

R01 đã đóng bằng commit local 9ae0a50 sau review 19 file và đối chiếu 10 SHA256 với evidence 300 tests; không chạy lại full để đóng R01 vì source không đổi. R02 mở rộng cùng [HTTP harness](../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java), dùng nguyên hai lệnh focused/full bên trên. Không cần runner, endpoint test hay profile mới.

59 ca mới kiểm tra POST/PATCH/DELETE bằng HTTP thật: ownership hai PT, role/anonymous, PT bị khóa hoặc thiếu profile, UTC/offset/microsecond, tương lai và 90 phút, thời gian sai, overlap/tiếp giáp, BOOKED và CONFIRMED độc lập, lịch sử/FK, PATCH thay thế và không mở lại DISABLED/slot quá khứ. Các đợt 2/8/20 request tạo chồng nhau yêu cầu đúng một 201, còn lại 409 và đúng một row DB; race PATCH với POST yêu cầu tối đa một thay đổi thắng. Hai ca giữ row lock trên kết nối PostgreSQL riêng, quan sát HTTP connection chờ Lock trong pg_stat_activity, commit booking CONFIRMED, rồi yêu cầu PATCH/DELETE trả 409.

R02 scenarios tự đăng ký UUID slot/booking đã tạo và cleanup đúng UUID sau từng test, theo thứ tự FK, trong transaction; không xóa theo khoảng giờ hoặc pt_id. Actor thiếu profile dùng email tổng hợp hợp lệ và BCrypt của bean ứng dụng. Tài khoản bị đổi status được khôi phục trong finally. Các slot legacy của fixture Task A vẫn là dữ liệu đọc một giờ hợp lệ theo V4; mọi slot tạo qua API R02 dài 90 phút. Không sửa lịch sử fixture để giả định đã có booking write/lifecycle.

Kết quả cuối: HTTP focused 142 passed và full regression 359 passed, 0 failed/errors/skipped; focused là tập con. Lượt HTTP đầu 138 passed/3 failed do email fixture vượt 64 ký tự ở local-part, đã sửa và chạy lại; không che lượt lỗi hoặc cộng dồn các lượt. Thời điểm, source hashes, giới hạn và hướng dẫn chạy lại nằm ở [báo cáo R02](evidence/R02_PT_AVAILABILITY_WRITE.md).

## Regression R03

R02 đã commit local 4d137d7 sau review 18 file và đối chiếu tám source hashes/Surefire 359 tests. Không thay code hoặc chạy lại full chỉ để đóng R02. Working tree R03 dùng nguyên runner và guard JDK 21/PostgreSQL test riêng ở trên; không thêm endpoint test, dependency hoặc profile.

Unit focused từ backend với JDK 21: `.\mvnw.cmd -B -ntp '-Dtest=BookingEligibilityValidatorTest,BookingPolicyServiceTest' test`. HTTP focused dùng runner không -FullSuite; full dùng -FullSuite như các lệnh phía trên. Không chạy Maven HTTP trực tiếp bỏ qua DB guard.

HTTP group BookingCreateCases nằm trong HttpBaselineTest: 56 invocations mới, tổng HTTP 198. Surefire hiện ghi một XML 198 testcase; console có thể gán aggregate vào nested class và outer class 0, không cộng lại tên suite hoặc gọi 198 là số HTTP requests. Unit mới có 22 invocations; 3 policy unit là regression cũ. Full 437 = R02 359 + 56 HTTP + 22 unit, không cộng focused/full hoặc test trùng nhau.

Các race giữ khóa PostgreSQL trên kết nối riêng, chờ một request rồi request thứ hai cùng bị block trước nhả khóa; quan sát pg_stat_activity wait_event_type=Lock, không gửi request tuần tự giả concurrency. Kiểm cả hai thứ tự thắng của booking/PATCH và booking/DELETE. Rollback test giữ INSERT booking xung đột chưa commit, cho HTTP tới INSERT và bị chặn bởi exclusion, sau đó commit xung đột; yêu cầu 409 và slot gốc AVAILABLE/không có booking. Không dùng trigger mới hoặc sửa schema để ép lỗi.

Policy dùng UUID riêng từng ca, Clock kiểm soát; membership fixture được snapshot/khôi phục trạng thái và ngày, tài khoản test được khôi phục sau mutation. Booking và slot tạo qua HTTP/SQL được đăng ký UUID chính xác để cleanup theo FK; không xóa theo Member/PT/range. Các ca intentionally inconsistent nhưng hợp lệ V4 kiểm phòng vệ service, không định nghĩa lifecycle mới. Evidence, failure/skipped và giới hạn nằm ở [báo cáo R03](evidence/R03_BOOKING_CREATE.md).

## M-01 regression

[Quyết định](decisions/2026-11-22_M01_PLAN_CREATE.md), [kết quả mới](evidence/M01_PLAN_CREATE.md), [chạy lại Web/DB](15_BOOKING_WEB_QUICKSTART.md#m-01--admin-tạo-membership-plan-22112026). Có executable Java mới nên chạy focused HttpBaselineTest rồi full bằng test-http-baseline.ps1/JDK21/DB riêng. MembershipPlanCreateCases nằm trong full, không cộng dồn. Admin client/widget riêng; UI Chrome/HTTP read-back/DB checks báo tách biệt. Không dùng668 lịch sử làm kết quả mới; không cần chạy Member/PT khi không sửa source/client/helper chung của hai app.

## Account/PT activation22/11 — cách chạy lại

[Contract và giới hạn schema](decisions/2026-11-22_ACCOUNT_PT_ACTIVATION.md), [evidence/hashes](evidence/ACCOUNT_PT_ACTIVATION.md). Trên JDK21 dùng guarded `backend/scripts/test-http-baseline.ps1` theo lệnh DB riêng đã có: thêm `-AccountFocused` để chạy HttpBaselineTest+AccountHttpTest+PtActivationServiceTest+TestSmtpActivationMailerTest; hoặc `-FullSuite` cho regression, không kết hợp hai switch. DB_PASSWORD chỉ process/secure prompt, truyền đúng64ký tự containerID đã inspect, không copy password vào lệnh/doc. Không bật activation flag/áp SQL candidate để lách blocker.

Flutter: ở Admin/PT chạy `flutter analyze`, `flutter test`, `flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1`; focused là `test/admin_account_test.dart` / `test/pt_activation_test.dart`. Unit SMTP dùng ServerSocket loopback/in-memory, không thư gửi người thật. Không coi test mockstore là bằng chứng transaction/concurrency OTP trên PostgreSQL.

## PT activation PostgreSQL rehearsal — quyền mới22/11

[Quickstart riêng](16_PT_ACTIVATION_REHEARSAL_QUICKSTART.md) thay giới hạn chờ schema trong phạm vi DB test riêng. Runner activation-rehearsal.ps1 tạo cặp DB mới mỗi run; focused65/full801 thực chạy, không cộng dồn. Có pre-Flyway guard và test schema/HTTP/SMTP/concurrency/rollback thật; default runner cũ vẫnV1–V6. UI13/HTTP4/DBaudit4 là checks riêng. [Evidence cuối](evidence/PT_ACTIVATION_POSTGRES.md). Không áp V7, clean/repair/out-of-order hoặc chạy DB chung; các đoạn gate503 cũ là snapshot default/release, không phủ định rehearsal đã đạt.

M-05/M-06 renewal/simulator (guarded/default-off): [quickstart](21_RENEWAL_SIMULATOR_QUICKSTART.md), [contract](decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md), [evidence](evidence/M05_M06_RENEWAL_SIMULATOR.md). Không dùng số I01 làm kết quả lượt này.

F-01 Core check-in/history: [contract](decisions/2026-11-24_F01_CHECKIN_CORE.md), [OpenAPI](api/openapi.yaml), [quickstart](22_CHECKIN_CORE_QUICKSTART.md), [evidence](evidence/F01_CHECKIN_CORE.md). Adapter identity chỉ simulated/test guarded default-off; không Face ID/liveness E2E.
