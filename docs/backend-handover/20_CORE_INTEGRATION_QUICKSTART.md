# I-01 — quickstart tích hợp Core trên DB test riêng

[Ứng viên migration/release gate](decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md), [evidence](evidence/I01_CORE_INTEGRATION.md). Baseline `9503110`. Không dùng DB chung/production; không áp V7 hoặc coi gap history là release-ready. Chỉ seed Admin cho E2E; dữ liệu tổng hợp cho bài upgrade/regression được tách khỏi DB E2E.

## Công cụ và authority

JDK21; Docker Desktop local Linux context; Flutter SDK/lock hiện có, Chrome và Playwright1.56.1 ngoài Git. `$private` là thư mục riêng bền dưới LOCALAPPDATA/Temp, ngoài sandbox phiên/Git. Không copy manifest hoặc credential của người khác. Khi tái dùng own container đã xác minh: full64hexID, image, label account-20261123, volume fitcenter_account_20261123_data, loopback15441, app role không đặc quyền phải khớp manifest. Tạo private scope mới chỉ ghi các run I-01; giữ authority cũ nguyên vẹn. Không Provision đè resource tồn tại.

```powershell
node backend/scripts/core-migration-inventory.mjs --verify
# Nếu chưa có resource: dùng Provision; nếu đã có, inspect authority trước khi start exact ID.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/core-integration-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $private
# Sau khi đối chiếu fullID từ manifest với docker inspect:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/core-integration-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Test luôn tạo **hai DB mới**. Empty và history migrate V1–V6; history seed synthetic legacy SUCCESS/FAILED/REFUNDED/CANCELLED/PENDING + nullable payment, snapshot; thêm V8/V9 giữ tất cả rows cũ; tạo PT state và genuine M03 receipt/snapshot; thêm V10 giữ nguyên. Assert checksum DB theo manifest; validate-only khi có V7 late phải fail, không migrate V7. Có transactional DDL rollback. Registry từng UUID được giữ private cho cleanup, không clean/reset/reseed thay migration.

Scoped full thêm `-FullSuite`; baseline15437 chỉ được runner riêng verify trước khi dùng, DB_PASSWORD nạp DPAPI vào **process** (không literal secret). Selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`; các integrated PT/Member/M03 thay ba lớp profile cũ. Booking HTTP/PG regression dùng baseline15437, integrated activation/schema dùng15441; **E2E ở dưới chỉ dùng một backend/DB15441**. Không gộp focused vào full.

## Chuẩn bị E2E Admin-only trên một pair DB mới

Không dùng DB history đã chứa fixture regression cho E2E. Chạy `NewRun` sau khi Test đã kết thúc; lưu lại nonce các run để cleanup. Dừng backend trước khi đổi current-run, không chạy Test/NewRun trong khi harness UI đang chạy.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/core-integration-rehearsal.ps1 -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
# JAVA_HOME/PATH chỉ process. Package backend từ source, không đổi default gates:
backend/mvnw.cmd -f backend/pom.xml -DskipTests package
backend/mvnw.cmd -f backend/pom.xml dependency:build-classpath -Dmdep.outputFile=$private/classpath.txt
# DB_PASSWORD chỉ process từ app.dpapi; $nonce lấy từ current-run.json.
$classpath = 'backend/target/classes;' + [IO.File]::ReadAllText("$private/classpath.txt").Trim()
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/CoreIntegrationDemo.java $private $nonce
```

Helper refuse DB có tables, guard host/port/role/namespace, migrate đúng9 scripts trên pair mới, chỉ INSERT Admin BCrypt thật. Không seed plan/Member/PT/Membership/payment/policy/slot/Booking. `demo-fixture.properties` CREATE_NEW trước INSERT, private Admin credential/UUID, không đưa Git. Nếu đã có file, không overwrite; đối chiếu/cleanup rồi dùng private run mới.

Build ba app với `flutter build web --no-pub --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:18084/api/v1` tại từng project ad/member/pt; SDK và pub cache ngoài Git. Không đổi source Dart/dependencies trong I-01. Tests/analyze không được gọi là đã rerun nếu chỉ build.

## Một backend, mail sink, ba Web app

Port18084/3000/3001/3002/11035/11036 trống; CORS chỉ localhost3000/3001/3002. Không Clock override, LAN/firewall hoặc wildcard. Chạy terminal riêng, hoặc Start-Process -WindowStyle Hidden, private PID/starttime registry.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/core-integration-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
node frontend/account-integration-mail-sink.mjs $private
node frontend/serve-booking-web.mjs ad
node frontend/serve-booking-web.mjs pt
node frontend/serve-booking-web.mjs member
# PGPASSWORD process từ app.dpapi; Playwright index.mjs nằm ngoài Git:
node frontend/verify-core-integration.mjs $private $playwright
```

Harness kiểm DB ban đầu Admin-only. Admin **UI gốc** tạo plan; Admin **HTTP thật** tạo Member/PT A/B chưa ACTIVE, PUT policy rõ ràng14/2/4/5 và M03 thu quầy/cấp Membership cho A. Member/PT A **UI gốc** email→SMTP OTP→password→ACTIVE→login; B activation qua HTTP+SMTP để kiểm ownership. Member M04 cùng UUID/date; PT UI tạo slot tương lai90phút; Member UI chọn PT/slot→CONFIRMED, hủy→AVAILABLE→hành động mới đặt lại (UUID mới), reload/login; PT original sessions cùng UUID/time/history. Chrome timezone America/Los_Angeles, UI vẫn VN. Không sửa dữ liệu để giả complete và không dùng fixture ACTIVE để thay activation.

Mail SMTP11035 và protected control11036 loopback, @example.invalid, inbox/OTP chỉ memory. Harness lưu intent trước write, response UUID ngay khi có, không replay write khi timeout. Nếu thất bại: đối chiếu registry/DB, cleanup exactUUID, archive attempt local; tạo E2E mới. Không tìm plan theo tên để đoán create success. Ảnh chỉ sau khi ra khỏi form chứa credential/OTP/password; ảnh lỗi masked nằm private.

## Cleanup và dừng đúng process

```powershell
node frontend/cleanup-core-integration.mjs $private
node frontend/cleanup-core-integration.mjs $private
# Dừng PID/starttime/command line đã xác minh: backend Java + wrapper, ba web, mail.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/core-integration-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Cleanup chỉ runs thuộc manifest I-01, seal UUID ledger trước DELETE, child rows phải suy ra từ owned UUID, snapshot rows ngoài ledger phải giữ nguyên. Giữ schema/history/volume. Không stop Docker Desktop/tài nguyên ngoài task. Nếu scoped full đã tự khởi động baseline15437, đối chiếu own container và không có session rồi dừng riêng; không dừng baseline đang được người khác sử dụng. Credentials/manifests/raw logs/build/SDK ngoài Git.
I-01 pin EOL ch?n SQL b?ng [.gitattributes](../../.gitattributes) ?? checkout m?i gi? ??ng bytes manifest d? core.autocrlf=true/false. Kh?ng ??i SQL/version/Flyway checksum; [hai th? nghi?m checkout ri?ng](evidence/I01_CHECKOUT_RESULTS.json) ki?m ??9file/mode. Kh?ng ch?y renormalize hay stage l?i migration.
