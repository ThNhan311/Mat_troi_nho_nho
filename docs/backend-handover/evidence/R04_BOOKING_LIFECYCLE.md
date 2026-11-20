# R04: kết quả booking cancellation và completion

Ngày thực hiện: 20/11/2026. Đã triển khai và kiểm thử ba endpoint Member cancel, PT cancel và PT complete. Ban đầu chỉ triển khai phần độc lập vì Topic11 không xác định rõ PT có được hủy session đã bắt đầu/kết thúc. Người dùng sau đó chốt **PT chỉ hủy CONFIRMED khi now < startAt**, bằng/sau trả 409 ERR_PT_CANCELLATION_WINDOW_CLOSED. Endpoint/tests PT cancel được bổ sung và chạy sau quyết định này; không coi kết quả 499 trước đó là bằng chứng PT cancel đã đạt. D01 service-start eligibility check vẫn chưa triển khai.

## Đóng R03 và Git

Review đủ 25 file R03 gồm untracked, code/tests/API/OpenAPI/quyết định và [evidence R03](R03_BOOKING_CREATE.md). Cả 15 executable source hashes khớp evidence; Surefire XML tại thời điểm đóng vẫn 437 passed, 0 failures/errors/skipped. Không có thay đổi executable source nên không chạy lại full chỉ để commit. Không phát hiện secret/token/mật khẩu thật, dữ liệu thật hoặc file Face trong phạm vi được stage.

Đã stage chính xác 25 file và tạo commit local `394a21f96c7c7458cc109c9f56a174beb1ccf62b`, message `feat(backend): add auto-confirm booking creation`, cha `4d137d703ab522e6f977d0e297f5a939a1011bcc`. Kiểm tra nhánh lifecycle chưa tồn tại rồi tạo `feature/backend-booking-lifecycle` từ commit R03. HEAD hiện tại vẫn `394a21f`; R04 chưa stage/commit. Không push/merge/reset/stash. Giữ nguyên các file untracked Face và tài nguyên ngoài task. Không tìm thấy AGENTS.md trong cây repository đã kiểm tra.

## Nguồn và phạm vi

Đọc lại Topic11_FITCENTER.docx đính kèm ngoài repository: UC-11/15/16, mục 1.5.6 và AC-BKG-04..09; SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`. Đọc nội dung OOXML, không giả định số trang hoặc copy tài liệu nguồn vào Git. Đối chiếu [D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md), [V4](../../../database/migrations/V4__pt_booking.sql), R01/R02/R03 và API conventions.

[Contract, lựa chọn triển khai và traceability](../decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md) được ghi/báo trước coding: response 200 BookingResponse hiện hữu, error envelope hiện có, repeated terminal request 409 và không đổi metadata. Member lấy policy hiệu lực R01, deadline equality cho phép, không kiểm membership ACTIVE. Future slot AVAILABLE; trường hợp policy deadline=0 và now=start được hủy nhưng slot DISABLED vì không còn tương lai. Complete chỉ CONFIRMED và now>=endAt, lưu completedAt UTC, slot DISABLED; không thay thế service-start eligibility check.

Khóa READ_COMMITTED, timeout 10 giây, **Member → PT → slot → booking**. Không khóa membership vì hai thao tác độc lập không cần eligibility. Projection BookingLink chỉ lấy identity trước khóa; sau khóa đọc lại booking và kiểm tra state/identity/time, account principal và không có booking CONFIRMED khác trên slot. Booking lock ở cuối không đảo thứ tự R02/R03. Mọi lifecycle thay count/overlap giữ Member lock; slot và booking chuyển nguyên tử, rollback cả metadata đã flush nếu cập nhật slot lỗi. Request cũ sau rebooking bị chặn bởi state cũ trước khi đổi slot.

PT cancel nhận reason không thiếu/null/blank/Unicode whitespace, tối đa 500 Unicode code points, lưu nguyên văn. PT ACTIVE sở hữu booking CONFIRMED; Clock lấy sau khóa/recheck, không dùng giờ request đến. Không yêu cầu policy hoặc membership Member ACTIVE. Thành công lưu actor PT/reason/cancelledAt, slot DISABLED. Terminal request với reason hợp lệ trả 409 ERR_BOOKING_NOT_CONFIRMED trước kiểm cửa sổ thời gian, không cập nhật metadata lần hai. OPEN-R04-PT-TIME đã đóng bởi quyết định người dùng, không gán quy tắc thời gian bổ sung cho Topic11.

## Diff thuộc R04

19 file: 7 production, 2 test và 10 tài liệu/OpenAPI; không có file Face.

- Production mới: [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/BookingLifecycleController.java), [BookingLink](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingLink.java), [PtCancellationRequest](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/PtCancellationRequest.java), [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleService.java), [validator](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleValidator.java).
- Production sửa: [BookingRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingRepository.java), [MemberRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MemberRepository.java), thêm projection/lock/query bảo vệ slot.
- Tests: [unit mới](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleValidatorTest.java), [HTTP harness](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) thêm BookingLifecycleCases.
- Tài liệu sửa: [API](../05_API_DOCUMENTATION.md), [testing](../06_TESTING_GUIDE.md), [business blockers](../07_BUSINESS_RULES_AND_BLOCKERS.md), [roadmap](../08_DEVELOPMENT_ROADMAP.md), [next tasks](../13_NEXT_DEVELOPER_TASKS.md), [harness](../14_HTTP_BASELINE.md), [OpenAPI](../api/openapi.yaml), [D01–D07](../decisions/2026-11-20_BOOKING_DECISIONS.md). Hai tài liệu mới là [contract/traceability R04](../decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md) và báo cáo này.

Không sửa entity, POM/dependency, application properties, runner, fixture hoặc V1–V6; không áp V7, alignment, onboarding BLOCKED, PUT policy, membership/payment write hoặc Face.

## Môi trường và kết quả thực chạy

Temurin JDK 21.0.13+9, Maven Wrapper 3.10.0, JVM UTC; không dùng Java 25 mặc định của máy. PostgreSQL 17.12, Docker desktop-linux local engine `npipe:////./pipe/dockerDesktopLinuxEngine`. Container `fitcenter-baseline-20261120-db`, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, label fitcenter.task=baseline-20261120, volume `fitcenter_baseline_20261120_data`, port `127.0.0.1:15437` → 5432. DB riêng `fitcenter_baseline_20261120_test`, role `fitcenter_baseline_app` không superuser/createdb/createrole/replication/bypassrls. Kiểm tra datasource/container/volume/port/role và history 1–6 success trước Spring/Flyway. Credentials role test và JWT sinh ngẫu nhiên trong process memory, không lưu/in giá trị thật.

| Lượt thực chạy | Passed | Failed | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| Unit phần độc lập, chưa có PT time rule (lịch sử) | 18 | 0 | 0 | 0 | 2026-11-20 14:57:34 |
| HTTP focused phần độc lập trước 5 complete-race cases cuối (lịch sử) | 237 | 0 | 0 | 0 | 2026-11-20 15:02:28 |
| Full phần độc lập, chưa có endpoint PT cancel (lịch sử) | 499 | 0 | 0 | 0 | 2026-11-20 15:04:24 |
| Unit sau PT cancellation rule | 21 | 0 | 0 | 0 | 2026-11-20 15:22:32 |
| HTTP/DB focused trước 5 ca recheck account/PATCH/DELETE cuối | 278 | 0 | 0 | 0 | 2026-11-20 15:23:13 |
| **HTTP/DB focused source cuối** | **283** | **0** | **0** | **0** | **2026-11-20 15:24:25** |
| **Full regression source cuối** | **543** | **0** | **0** | **0** | **2026-11-20 15:25:18** |

Full cuối **543 = 437 R03 + 21 lifecycle unit + 85 lifecycle HTTP/DB cases**. So với lượt độc lập 499: thêm 3 unit boundary và 41 HTTP/DB invocations (gồm hai invocations mới của các parameterized tests cũ). Harness cuối 283 = 198 regression + 85 lifecycle; 85 gồm 84 HTTP scenarios và 1 service/transaction rollback trực tiếp trên PostgreSQL. Surefire có 19 XML suites, HttpBaselineTest một XML chứa 283 testcase; không cộng nested/outer aggregate hai lần. Focused là tập con/lượt lặp, không cộng vào full. Không có backend test failure cần sửa. Preflight đầu tiên của lượt độc lập gặp PostgreSQL đang startup, dừng trước Spring/tests; sau pg_isready đã xác minh lại datasource rồi chạy, không coi lần đó là test failed/passed. Lượt bổ sung PT cancel xác minh readiness thành công trước tests.

Skipped=0 là kết quả JUnit thực của suite cuối, đã gồm PT cancel sau quyết định. Các lượt lịch sử trước đó chưa có PT cancel không được đổi nghĩa thành đã chạy endpoint này. Không gọi kết quả này là E2E toàn hệ thống. Các test legacy tên DatabaseAlignmentTest dùng default profile V1–V6, không dùng profile alignment.

Các nhóm thực kiểm tra:

- Member cancel 200, đủ 11 DTO fields/UTC, CANCELLED/by MEMBER/cancelledAt, DB rows, lịch Member/PT, available list và Member khác đặt lại 201. Membership inactive/PENDING_ACTIVATION/SUSPENDED/EXPIRED/CANCELLED không cản quyền hủy của chủ booking; account vẫn phải ACTIVE.
- Deadline trước/bằng/sau ở HTTP microsecond, unit nanosecond; policy tùy chỉnh và deadline=0; policy absent/inactive/future 404 BOOKING_POLICY_NOT_FOUND không mutation. Không fallback.
- Complete trước/bằng/sau endAt, completedAt, DB/calendar, slot DISABLED không reopen; thiếu policy hoặc membership expired không cản complete. Đây không phải D01 service-start check.
- Thiếu token 401; sai role 403; sai owner/PT, UUID không tồn tại 404, UUID không hợp lệ 400; account bị suspend không thao tác. Terminal CANCELLED/COMPLETED không chuyển lại, metadata/slot bất biến.
- Cancel/cancel, complete/complete và Member cancel/complete cạnh tranh. Tại endAt chỉ complete hợp lệ; kiểm cả hai thứ tự tranh khóa. Bổ sung PT cancel/PT cancel (reason đầu tiên bất biến), PT cancel/Member cancel (đúng một actor và slot outcome), PT cancel/complete cả trước start và tại end, cả hai thứ tự enqueue; không bao giờ hai transitions cùng thắng.
- Cancel/rebook, Member cancel/PATCH/DELETE và complete/PATCH/DELETE kiểm cả hai thứ tự enqueue. Giữ PT row lock bằng JDBC ngoài, quan sát cả hai HTTP requests đang chờ Lock trước khi release; không chỉ gửi tuần tự. Assert state/time/FK/ownership, history và replacement slot ID khi PATCH sau cancel. Complete không mở lại slot quá khứ.
- Request hủy cũ sau rebooking trả 409, metadata booking cũ và booking/BOOKED slot mới không đổi. Request book đã quan sát slot cũ có thể 409 do version/state guard; request mới sau refresh đặt lại thành công.
- Rollback thật: fixture cố ý có CONFIRMED trên DISABLED slot và slot AVAILABLE chồng giờ nhưng hợp schema; Member cancel flush metadata CANCELLED rồi mở AVAILABLE gặp exclusion 409 ERR_CONFLICT. Assert full DB rows booking/slot rollback nguyên trạng. Không thêm trigger, migration hoặc endpoint phục vụ test.
- PT cancel happy path HTTP 200, đủ DTO/metadata UTC/reason tiếng Việt và Unicode được giữ nguyên, lịch Member/PT khớp; slot DISABLED vắng trong available list, rebook 409 ERR_SLOT_NO_LONGER_AVAILABLE. Không có policy và membership ở bốn trạng thái inactive vẫn hủy được.
- PT cancel trước/bằng/sau startAt ở HTTP microsecond và unit nanosecond. Request đến trước start nhưng đang chờ PT lock: Clock dịch đến đúng/sau start rồi nhả khóa, trả 409 ERR_PT_CANCELLATION_WINDOW_CLOSED và DB rows không đổi. Account PT bị suspend khi đang chờ thì recheck trả 403; token PT đã suspend trước request trả 401.
- PT cancel role ADMIN/MEMBER 403, anonymous 401, PT khác/missing UUID 404, UUID sai 400. Reason missing/null/empty/whitespace Unicode hoặc 501 ký tự ASCII/emoji trả 400 không mutation; đúng 500 emoji hợp lệ. Terminal CANCELLED/COMPLETED/repeated cancel trả 409, reason/time/slot không thay lần hai.
- PT cancel/create tranh cùng BOOKED slot cả hai thứ tự, PT cancel thắng và create 409; slot DISABLED không đặt lại được. Member cancel rồi stale PT request/rebook tranh nhau cả hai thứ tự: booking mới CONFIRMED đúng Member B, slot BOOKED và booking cũ giữ nguyên; request PT cũ lặp tiếp vẫn không tác động. PT cancel/PATCH/DELETE cả hai thứ tự giữ DISABLED và FK/time, không reopen.
- Rollback PT cancel: gọi service thật trong outer transaction PostgreSQL, kiểm booking CANCELLED và slot DISABLED đã được flush/read bằng JDBC cùng transaction rồi chủ động throw để rollback; full-row snapshots sau rollback bằng trước. Đây là một DB integration case, không tuyên bố nó là lỗi HTTP hoặc SQL failure được quan sát. Cộng với Member constraint failure ở trên, kiểm cả rollback sau flush và lỗi constraint qua HTTP mà không sửa schema/trigger.

Assertions gồm status, error code/envelope/correlation, DTO/content/time, DB rows/counts, lịch đọc và ownership. UUID fixture/HTTP được ghi registry và cleanup chính xác theo FK; không truncate hoặc xóa theo member/PT/range. Hậu kiểm users/members/trainers/plans/memberships/slots/bookings/policy/notifications đều 0 dòng như trước test; history đúng 1–6, tất cả success. DB riêng được dừng sau kiểm tra, giữ named volume.

OpenAPI YAML/structure **19 paths, 123 local references** đạt bằng SnakeYAML 2.6 cached/JDK 21; kiểm ba POST lifecycle với auth/UUID/200/400/401/403/404/409, PT requestBody/reason required/maxLength=500 và error cửa sổ thời gian. Không tuyên bố chạy OAS validator chuyên dụng. Docs hoàn thiện sau full; executable source giữ nguyên hashes dưới đây.

## Chạy lại và giới hạn

Theo [testing guide](../06_TESTING_GUIDE.md) và [runner guide](../14_HTTP_BASELINE.md), cấp credentials test qua secure prompt hoặc process environment, không hardcode hay đưa password thật vào command line. Nếu role đang có password ngẫu nhiên của lượt này, cần cấp lại bằng quyền quản trị test riêng đã xác minh. Không lưu password cũ trong repo/báo cáo. Chỉ thay process JAVA_HOME/PATH để dùng JDK 21.

```powershell
# Từ backend, JDK 21, unit không cần DB:
.\mvnw.cmd -B -ntp '-Dtest=BookingLifecycleValidatorTest' test

# Từ repository root, HTTP focused rồi full khi cần:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome '<absolute-path-to-jdk-21>' -ExpectedContainerId '<verified-full-container-id>' -StartDatabase -FullSuite
```

Bypass chỉ cho child process; không đổi execution policy máy. Runner xác minh target trước Spring/Flyway và tự dừng DB nếu chính runner đã khởi động nó. Nếu DB đã chạy từ bước chuẩn bị, sau test dừng đúng container đã kiểm tra; giữ volume.

Không còn blocker PT cancellation time: người dùng đã chốt chỉ trước startAt và tests mới đã chạy. **D07 PT cancel/completion đã triển khai/kiểm thử; D01 recheck trước bắt đầu dịch vụ vẫn chưa triển khai.** Completion không thay thế service-start check. Không có blocker schema buộc migration cho R04. Không bảo đảm invariant cho writer bên ngoài không tuân thủ giao thức khóa; không chạy frontend/Face/payment/performance hoặc E2E toàn hệ thống. R04 giữ chưa stage/commit để review, không push/merge.

## SHA256 executable source của working tree đã full-test

Base commit `394a21f96c7c7458cc109c9f56a174beb1ccf62b` + 9 file dưới đây. Tài liệu/OpenAPI có thay đổi sau test, không thay executable source.

| File | SHA256 |
|---|---|
| backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingRepository.java | 4FF7F0794843C3C65D26B92052C825C3599B370893F052BF0E2DBBA1E1ABE016 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MemberRepository.java | 7B074B8BE7208257E23F9F7F3974AE0C88E6BFDA7EE0E7623FC08FFEA817F192 |
| backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java | 0DB37F4E167B06411433E5A48EBC926DD8B5BE76384A2B3E435F30D6769C4E74 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/controller/BookingLifecycleController.java | 27FD475C0B653F185E64D1F833670C363BA5112E3ED08E0E50F41803D55B31F7 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingLink.java | 0D9945E8BD015FAD56EE3FFC946A8ECDDB940E24866D2D43DD693426AE8728C4 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/PtCancellationRequest.java | A4F93C3C933CC10FC973CC4480C8AF0A28D9265C71AC81E7CFC4F4FCA8CE743A |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleService.java | A3B8836E10CB009BE72145701946D90CF267CD5A2E76296AC29CD36464EE0BE9 |
| backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleValidator.java | CF9B8BE0C33959F4B3284507E1FEE1D50939E92BCB332CD67BE2D3BFEFEC69B0 |
| backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleValidatorTest.java | 46045FC78467A7CF85633D379591B5DB64752A712F1B2F91B5A487588C6D1E49 |
