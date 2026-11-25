# I-01 — Account + Membership + Booking integration rehearsal

Base `950311082d4cc5b2c5b85b1a3f8cd644246cd932`, branch `feature/core-integration-rehearsal`, source cuối23/11/2026. [Chạy lại](../20_CORE_INTEGRATION_QUICKSTART.md), [inventory/quyết định release](../decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md). SHA commit đóng task tra Git history; báo cáo không tự tham chiếu SHA của chính commit chứa nó.

## Kết quả thực chạy

| Nhóm | Passed | Failed/errors/skipped | Phạm vi |
|---|---:|---|---|
| Scoped full Backend/JDK21 | **918** | **0/0/0** | 33 XML suites tươi, gồm integrated PT23/Member24/M0354/schema5 và candidate4 |
| Focused Backend | 163 | 0/0/0 | Tập con full; **không cộng** vào918 |
| Chrome UI thật | **26 checks** | 0/0 | Admin/Member/PT Web gốc, một backend/DB/mail sink |
| HTTP thật trong harness E2E | **29 checks** | 0/0 | Khác JUnit/widget, không cộng với tests |
| DB assertions trong E2E | **9 checks** | 0/0 | UUID/time/state/ownership và payment snapshot |
| Flutter Web build | 3 apps | 0 failed | Cùng API18084; không sửa Dart hoặc pubspec/lock |
| Cleanup cuối | 30 checks/10DB | 0 failed | Chạy lại cùng30checks đạt; không cộng thành60 |

[JUnit suites/commands](I01_TEST_RESULTS.json), [UI/HTTP/DB read-back](I01_UI_HTTP_DB_RESULTS.json), [hashes](I01_SOURCE_HASHES.json), [migration preservation](I01_MIGRATION_RESULTS.json), [Flyway histories thực tế](I01_APPLIED_INVENTORY.json), [cleanup](I01_CLEANUP_RESULTS.json), [stop](I01_STOP_RESULTS.json).

Selector full: `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`. Ba lớp PostgreSQL profile riêng cũ không chọn vì đã có lớp integrated tương ứng; không gọi chúng là passed/skipped. Unit/controller/mail/guard/Booking HTTP regression vẫn chạy. Booking HTTP/PG của full dùng baseline15437 đã guard; integrated activation/M03/schema dùng15441. **E2E mới bên dưới dùng duy nhất backend18084 + một DB15441 + mail11035/11036**, không đổi Clock server. Không gọi đây là E2E toàn FitCenter.

Không rerun Flutter analyze/widget tests vì không đổi source Dart/dependencies. Không lấy Member60/PT55/Admin36 lịch sử làm lượt mới. Rebuild cả3 app JS Web cho cùng API URL rồi chạy Chrome thật1024×768, timezone America/Los_Angeles để kiểm giờ VN. Backend production Java, gates mặc định, V1–V6/V8/V9/V10 và source UI sản phẩm không đổi; chỉ thêm runner/manifest/test/helper/docs/evidence.

## Migration và dữ liệu lịch sử

Ứng viên được pin **1,2,3,4,5,6,8,9,10**, không đổi số/bytes migration đã công bố. Database ref558fb03 đã fetch, V7 SHA-256 `668fdd672fdcff04e89525b3cadec3bc957f186f38fe0065dc4417a6f1b29b41`, Flyway checksum `-349926232`, **không thực thi**. Manifest giữ path/checksum/phụ thuộc và các remote SQL refs đã biết.

Hai lượt focused/full, mỗi lượt có DB empty/history mới. History: migrate1–6 → seed synthetic historical rows → snapshot → migrate8/9 → so sánh exact rows cũ → thêm PT activation completed và genuine service-written M03 receipt/audit/snapshot → snapshot → migrate10 → exact snapshot bằng nhau. Giữ6 payment legacy gồm SUCCESS, REFUNDED, FAILED, CANCELLED, PENDING, payment chưa link; date/null semantics không đổi. Không reseed sau migrate để giả preservation. Các DB E2E là pair **khác** hoàn toàn, không dùng lịch sử/ACTIVE fixtures để bỏ qua luồng account.

Candidate tests đối chiếu CRC32 DB với frozen manifest trên cả2 DB, kiểm legacy rows/receipt/PT state, transactional DDL rollback và validate-only thêm V7 sau10 thất bại mà không DDL/drop. Integrated M03 tests kiểm retry/idempotency/duplicate receipt/concurrency/fault rollback; PT/Member tests kiểm OTP expiry/attempt/resend/grant, role-isolation, password race/rollback và Clock sau lock. Boundary lifecycle dùng tests, không sửa dữ liệu/Clock hoặc đợi90phút để giả complete.

Inventory thực tế I-01 xác minh10 DB riêng (2pair regression + 3pair E2E kể cả failed attempts), từng version/script/checksum/success, app role không đặc quyền, container/image/volume/port đã guard. Chưa có inventory DB chung/đồng đội; **không kết luận V7 chưa áp ở đó, releaseReady=false**. V7 DROP periods chưa backfill, mapping initial COUNTER so với periods còn lệch; cần inventory/backup/mapping/ordering được đồng bộ trước release. [Đường phát hành có điều kiện](../decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md).

## E2E cuối — đối tượng nghiệp vụ đều qua API/UI

DB ban đầu chỉ có một Admin BCrypt tổng hợp. Không seed plan/Member/PT/Membership/payment/policy/slot/Booking. Các tài khoản B cũng Admin tạo và kích hoạt thật bằng HTTP+SMTP, không seedACTIVE.

| Bước | Bằng chứng thực tế |
|---|---|
| Admin tạo gói | UI MembershipPage gốc, POST201,30ngày/123456.78/UUID; [ảnh](core-integration/admin-created-plan.png) |
| Admin tạo Member/PT A/B | POST Admin account APIs thật201, DISABLED/activationPending, userId khác profileId |
| Thu quầy/cấp Membership | POST M03 thật201, giá plan server, receipt/idempotency/snapshots; User vẫnDISABLED |
| Booking policy | Admin PUT thật14/2/4/5, không seed/fallback |
| Member/PT A activation | UI gốc email→SMTP loopback→OTP→grant→password→ACTIVE→login; [Member](core-integration/member-activation-active.png), [PT](core-integration/pt-activation-active.png) |
| Member xem Membership | M04 UI cùng UUID/start/end/ACTIVE với M03; [ảnh](core-integration/member-m04-real-activation.png) |
| PT tạo slot | UI Lịch làm,90phút tương lai, UUID thật/AVAILABLE; [ảnh](core-integration/pt-created-available.png) |
| Member chọn PT/slot, đặt | UI gốc POST201/CONFIRMED, đúng UUID owner/PT/slot/time; [ảnh](core-integration/member-confirmed.png) |
| Đọc hai phía + PostgreSQL | Member/PT API cùng Booking UUID/time, DB slotBOOKED, slot vắng khỏi available |
| Ownership/quyền | B lịch rỗng; MemberB cancelA404/ERR_NOT_FOUND theo convention che ownership; sai role403, anonymous401, không mutation |
| Member hủy rồi đặt lại | UI cancel200/CANCELLED→slotAVAILABLE; hành động mới POST201/newUUID. Request cancel cũ409/ERR_BOOKING_NOT_CONFIRMED không đổi booking mới/slotBOOKED |
| Reload/login | Member M04 và history cùng UUID; PT login/session tải lại có cả CANCELLED và CONFIRMED; [Member](core-integration/member-reloaded-history.png), [PT](core-integration/pt-reloaded-sessions.png) |
| Bảo toàn dữ liệu | Account activation và Booking create/cancel/rebook không đổi Membership/payment/receipt/plan snapshot |

## Lỗi đã sửa trong harness và giới hạn

Ba lượt UI trước chưa đạt: tên bảng helper sai `booking_policies` thay vì `booking_policy` (preflight, chưa write); helper chọn ô giờ cuối làm đảo start/end (form chặn trước slotPOST); cuối lượt3 chờ GET khi đổi tab PT vốn dùng state đã tải. Đã sửa picker chọn ô đầu, PT bấm **Tải lại**, cleanup/reconcile đúng UUID rồi chạy **toàn bộ lượt mới trên pair DB mới**. Chỉ số26/29/9 và10ảnh là lượt cuối; không lấy kết quả phần trước thay bằng chứng code cuối. Backend/UI sản phẩm không cần sửa. Export metadata xử lý UTF16 log PowerShell5; private PID registry được parse lại cấu trúc trước stop và xác minh creation time/command, không dừng PID theo tên suy đoán.

Chưa kiểm chứng production mail/gateway/renewal/Workout/Face, chưa merge/deploy hoặc release canonical. Không apply V7, out-of-order, clean/repair/history edits, migration renumber hay shared DB. Chưa chạy complete cho session tương lai.

## Cleanup/Git

Cleanup exactUUID registry trên10DB,30checks, lặp lại đạt; rows ngoài registry giữ nguyên, schema/history/volume còn. Dừng own Java/wrappers/3web/mail + DB test, ports3000/3001/3002/18084/11035/11036/15441/15437 đóng. Volume account/baseline giữ lại; Docker Desktop và tài nguyên ngoài task không đổi. Credentials/OTP/grant/token/private manifests/raw logs/SDK/cache/build nằm ngoài staged scope. Đã xem10ảnh cuối, không có credential/OTP/token.

Git từ9503110, nhánh chức năng riêng; review rồi commit/push thường, không merge/force. Bốn research untracked và Face checkout gốc giữ nguyên. Remote review23/11:0workflow/0run/0deployment/0webhook, **không gọi CI pass**. SHA local/remote cuối kiểm qua Git sau push, không ghi self-SHA vào báo cáo.
## B? sung review checkout sau checkpoint093c593

Git autoCRLF c? th? ??i bytes SQL sau checkout m?i. Pin [.gitattributes](../../../.gitattributes) theo representation ?? test; **2 th? nghi?m checkout ??c l?p**, m?i mode true/false ki?m ??9SQL b?ng SHA-256, ??u ??t. Ch? test t?i l?p checkout, kh?ng c?ng th?nh JUnit918 ho?c UI checks. L?n pin th? ??u ch?a ??ng EOL V9 ???c assertion ph?t hi?n tr??c khi s?a pin theo bytes th?c t?; kh?ng SQL n?o b? s?a/?p l?i. [K?t qu?](I01_CHECKOUT_RESULTS.json). To?n b?221hash UI/runtime v?10hash test/runner v?n kh?p l??t core, Java/Dart/SQL/helper executable kh?ng ??i; kh?ng l?p full/UI ch? v? b? sung c?u h?nh checkout.
