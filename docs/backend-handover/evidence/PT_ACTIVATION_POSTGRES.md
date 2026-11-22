# PT activation PostgreSQL rehearsal — bằng chứng 22/11/2026

Branch **feature/pt-activation-postgres-rehearsal**, source base **66a70311517ccd0bf287eff45b476f1ce5138a16**. Task thay đổi working tree được test trước commit; xem [hashes](PT_ACTIVATION_POSTGRES_HASHES.json) và [checks](PT_ACTIVATION_POSTGRES_CHECKS.json). [Quyết định/schema/order](../decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md). Các báo cáo account gate503 cũ là lịch sử, không dùng thay kết quả task này.

## Phạm vi đạt

[V8](../../../database/activation-rehearsal/V8__pt_account_activation.sql) thêm riêng bảng OTP/grant/counter, giữ canonical V1–V6 và dữ liệu membership/payment. Default profile vẫn activation=false/503; chỉ profile rehearsal đã guard bật tính năng. Không V7, out-of-order, sửa history, clean/repair hoặc DB chung. Không API nghiệp vụ mới hay đổi Dart/theme/navigation.

Container PostgreSQL test mới **3861f4ddcc45cb5d71a1fa74bfbf562f64145d444a575e49f4ebb7430b2ee78c**, image cache cùng baseline, Docker desktop-linux local named pipe; volume fitcenter_activation_20261122_data, loopback15439, role fitcenter_activation_app không quyền admin. Mỗi lần test dùng hai DB mới, không reset DB cũ. JVM Temurin21.0.13+9, UTC. Runner kiểm identity trước Flyway; guard trong app kiểm lại đích/role/location trước migrate.

## Tests đã chạy

| Nhóm | Passed | Failed/errors | Skipped | Phạm vi |
|---|---:|---:|---:|---|
| Full Backend regression | **801** | 0/0 | 0 | 762 baseline +39 mới, trong một lượt full |
| Focused cuối | **65** | 0/0 | 0 | Tập con của full, không cộng dồn |
| Schema rehearsal | 10 | 0/0 | 0 | Đã nằm trong full |
| HTTP/PostgreSQL activation | 20 | 0/0 | 0 | Đã nằm trong full |
| Guard unit | 9 | 0/0 | 0 | Đã nằm trong full |

Focused65 gồm schema10 + HTTP20 + guard9 + OTP unit23 + SMTP unit3. Full dùng guarded baseline cũ V1–V6 đồng thời hai DB rehearsal mới; không cộng HTTP20 hoặc focused vào801. Surefire report counts/hashes trong CHECKS; không sao chép raw reports/logs có environment vào Git.

Schema tests thực sự migrate DB trống V1–V6 rồi V8; DB history seed V1–V6 với User/profiles/plan/memberships/bookings/slots và payment SUCCESS có period_start/period_end trước V8. Snapshot toàn bộ rows canonical trước/sau bằng nhau, periods còn nguyên. Kiểm FK PT, role/counter/phases/nullable digest pairs, unique grant và rollback failed transaction. Validate/rerun V8 không mutation; V7 đến sau bị chặn, V7 thật của Duy chỉ validate-only. Fault migration DDL trên DB empty rollback cả table/history, không repair.

HTTP20 dùng server random loopback port, PostgreSQL thật, JavaMail gửi SMTP thật vào sink memory: DISABLED login401/noJWT; issue202/digest BCrypt/TTL300s; verify299s được,300/301s hết hạn; sai mã/5 attempts commit đủ; resend59 bị chặn/60 được, max5/giờ và đúng1giờ mở lại; grant một lần/TTL; password BCrypt→ACTIVE→login PT; MEMBER/unknown/legacy/suspended không kích hoạt; JSON/password byte validation; SMTP failure rollback challenge; DB fault rollback verify và password/User/audit/state. Dữ liệu payment periods cũ không đổi.

Concurrency dùng barrier và kết nối PostgreSQL giữ User row lock, **quan sát tất cả contenders wait_event_type=Lock trước nhả**, không gửi tuần tự: verify/verify một grant; password/password chỉ một ACTIVE/audit; first-send/first-send chỉ một mail/state;5 wrong attempts không mất increment; request đến299s chờ khóa đến300s bị expiry; password/resend không dùng grant đã thu hồi. Clock kiểm soát chỉ trong tests, production TimeConfig không đổi.

## UI + SMTP + DB thật

Backend package thành công. Flutter Admin/PT **Web build exit0** với API_BASE_URL=http://127.0.0.1:18082/api/v1. Dart source không đổi nên không chạy lại analyze/widget tests; Admin73/PT55 của task trước không được tính là tests mới. Helper Node đã syntax-check và thực chạy.

Chrome headless thật, viewport1024×768, timezoneAmerica/Los_Angeles. **13 UI checks passed,0failed/skipped**, **4 HTTP checks riêng**, **DBprepare2/audit4 assertions riêng**. Flow:

1. Login Admin gốc, list profiles thật, tạo PT201 DISABLED với UUID User/Profile riêng; chỉ một UI create.
2. PT login gốc → email → request202/no-store; mail sink loopback nhận đúng recipient tổng hợp, OTP chỉ memory.
3. UI nhập OTP → verify200/grant → form password → password200 ACTIVE, không tự login/JWT ở bước activation.
4. Về login, email/password →200 rolePT, Home/navigation gốc. Reload mất memory session; login lại200 vẫn ACTIVE.
5. HTTP bổ sung: trước activation login401; lấy mail sink có kiểm key private; grant replay400; PT Bearer GET slots200 array.
6. DB cùng **User b8867ebd-2c69-4341-bba8-356adf14f1fa**, **PT profile 8dfb7266-de11-4c79-b630-d3095c5d062f**: ACTIVE/BCrypt, OTP+grant null, completedAt có, đúng hai audit và actor; snapshot ngoài account không đổi.

Admin/PT account mới được tạo qua UI; baseline actors/membership/payment/session do fixture SQL, không quảng bá tạo qua UI. Mail sink không phải email nhà cung cấp thật; không gửi người thật. **Lát cắt E2E PT activation trên môi trường rehearsal đã đạt**, không E2E toàn FitCenter hoặc production rollout.

| Ảnh đã xem,1024×768 | Ý nghĩa |
|---|---|
| [Admin tạo PT](pt-activation-postgres/admin-created-disabled-pt.png) | DISABLED, UUID thật |
| [Email](pt-activation-postgres/pt-activation-email.png) | Form gốc |
| [OTP prompt](pt-activation-postgres/pt-activation-otp-prompt.png) | 202 thực, chưa nhập code khi chụp |
| [Password form](pt-activation-postgres/pt-activation-password-form.png) | Chỉ sau verify200, chưa nhập password khi chụp |
| [Kích hoạt xong](pt-activation-postgres/pt-activation-complete.png) | ACTIVE từ server |
| [PT Home](pt-activation-postgres/pt-activated-original-home.png) | Login thật, theme/navigation gốc |
| [Login lại](pt-activation-postgres/pt-activated-relogin.png) | Trạng thái persisted từ PostgreSQL |

Ảnh không chứa password, OTP hoặc token dạng rõ; chỉ dữ liệu tổng hợp, không người thật/Face. Private credentials/manifest/control key/raw logs ngoài Git; SMTP bodies/codes và grant chỉ memory. Không mở DB ra LAN, đổi firewall hay global PATH.

## Failures đã sửa

- Focused đầu26passed/2setup errors do JVM Asia/Saigon không được image PostgreSQL nhận; guard fail trước migration. Cố định JVMUTC trong runner.
- Windows PowerShell coi native stderr thông báo JAVA_TOOL_OPTIONS là lỗi terminating; chuyển ErrorActionPreference chỉ quanh Maven, vẫn kiểm exit code và fresh JUnit. Attempt này chưa có kết quả test mới.
- Guard URL ban đầu so regex cả JDBC URL, từ chối suffixquery do PGSimpleDataSource sinh; đổi URI host/port/path + current_database/current_user/privileges, thêm guard test. Lượt đó26passed/2setup errors, không dùng làm pass.
- Sau sửa: focused55pass, thêm guard/V7 thật rồi focused65pass và full801pass. Không tính55 hoặc65 thêm vào801. Không sửa logic OTP để làm tests vượt qua.

## Cleanup và giới hạn release

Audit4 trước cleanup; UI cleanup5 assertions rồi no-op1. Cả3 lượt có fixture (focused55,focused65,full801) cleanup đúng registry UUID hai lần; các DB attempt setup chưa có dữ liệu fixture được giữ trong volume. Không truncate/broad delete/clean/repair. Membership/payment được chứng minh giữ nguyên khi migration/UI; sau đó dữ liệu tổng hợp được cleanup có chủ đích.

Đã dừng Java32516/wrapper24364/NodeAdmin28792/PT9124/SMTP30272 sau kiểm parent/commandline; container rehearsal đã dừng, baseline do full runner start cũng dừng, giữ hai volume. Ports15439/15437/18082/11025/11026/3001/3002 không còn listen. Không dừng Docker engine/tài nguyên đồng đội.

Chưa release production: cần Duy đồng bộ canonical path/version/order (V7 trước V8 nếu giữ numbering) và rủi ro backfill V7. Rehearsal history1–6,8 không được chữa bằng out-of-order/history edits; dùng DB test mới cho release sequence. Default activation vẫn503. Chưa MEMBER activation/production SMTP/Membership/Payment/Workout/Face. [Chạy lại](../16_PT_ACTIVATION_REHEARSAL_QUICKSTART.md), [PROJECT_STATUS](../../PROJECT_STATUS.md).
