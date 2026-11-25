# MEMBER activation — integrated rehearsal quickstart

> Hướng dẫn lịch sử tại commit `9503110`. Với source hiện hành, dùng [portable setup Core](../INTEGRATION_SETUP.md) và `backend/scripts/core-readiness.ps1`; không áp candidate/authority cũ lên checkout mới. Các lệnh bên dưới được giữ để đọc evidence của task gốc.

[Contract/decisions](decisions/2026-11-23_MEMBER_ACCOUNT_ACTIVATION.md), [evidence](evidence/MEMBER_ACCOUNT_ACTIVATION.md). Không dùng DB chung/production. Default gates Member/PT/M03 false; chỉ profile account-integration-rehearsal bật trong target guard. Không compose hai profile rehearsal cũ hoặc tắt guard.

## 1. Tools và DB riêng

JDK21 đã verify; Flutter tương thích lock hiện có, không pub upgrade. `$private` là directory riêng **ngoài Git**, dưới LOCALAPPDATA/Temp, nên đặt ngoài thư mục sandbox phiên có thể bị dọn. `$JavaHome` đúng JDK21, `$verifiedId` là full64hex containerID được đọc từ manifest rồi đối chiếu docker inspect; không lấy ID từ ví dụ cũ. Không ghi đè manifest/credential/resource tồn tại. Container/volume account-20261123 và loopback15441 phải chưa collision ở Provision; runner dùng cached baseline PostgreSQL image.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/account-integration-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $private
# Inspect exact ID/label/image/volume/loopback mapping từ account-resource.json, rồi:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/account-integration-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/account-integration-rehearsal.ps1 -Action Verify -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Test tạo hai DB mới, never clean/reset. Empty:1–6,8,9→10; history:1–6,8,9 + dữ liệu PT/counter M03 tổng hợp, snapshot trước/sauV10 bằng nhau. Không applyV7, outOfOrder=false/clean-disabled=true. Role fitcenter_account_app không superuser/createdb/createrole/replication/bypassrls; guard JDBC127.0.0.1:15441/fitcenter_account_<nonce>_(empty|history)_test + flag và đúng4Flyway locations trước DDL. History1–6,8,9,10 chưa là canonical release.

Mỗi Test tạo run mới và registry run-<nonce>-fixture.properties, account-test-ids/m03-test-ids TSV; giữ private files để cleanup. Khi own container đã dừng: inspect theo manifest rồi `docker --context desktop-linux start $verifiedId`; không Provision đè. Test cần fresh DB nên không gọi Maven trực tiếp lên DB đã migrated.

Full thêm `-FullSuite`, nạp DB_PASSWORD baseline15437 từ DPAPI vào **process env**; baseline runner verify đúngcontainerID/volume/history/role. Selector `-IntegratedAccountSuite` không chọn3 lớp PG profile riêng cũ; thay bằng contract Member/PT/M03 trên integrated profile. Các PT unit/mail/guard vẫn chạy. Không gọi skipped0 là đã chạy3lớp không chọn hoặc cộng focused159 vào full914.

## 2. Build và chỉ seed Admin/plan

JAVA_HOME/PATH chỉ process; xác minh java -version21. Repository root: `backend/mvnw.cmd -f backend/pom.xml -DskipTests package`. Tạo classpath ngoài Git: `backend/mvnw.cmd -f backend/pom.xml dependency:build-classpath -Dmdep.outputFile=<Temp-path-tuyệt-đối>`, đọc vào `$classpath`.

Từ project Member: `flutter analyze --no-fatal-infos`, `flutter test --reporter expanded`; build cả Member/Admin với `flutter build web --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:18084/api/v1`. Không sửa SDK constraints/dependencies. PT Dart không đổi nhưng tests đã rerun. Analyze Member còn58info, không strict lint clean.

Nạp DB_URL current-run.history (jdbc:postgresql://127.0.0.1:15441/...), DB_USERNAME=fitcenter_account_app, DB_PASSWORD từ app.dpapi vào process only. Không literal password trong command history; không in secret.

```powershell
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/AccountIntegrationDemo.java $private $nonce
```

Seed chỉ **Admin ACTIVE + plan30ngày/100000**, BCrypt thật. File `demo-fixture.properties` riêng, CREATE_NEW trước SQL; giữ registry run-fixture gốc, không seed Member/Membership hoặc ghi đè credential. Admin/plan là fixture, **Member account và Membership phải do UI/API thật** ở bước sau.

## 3. Chạy UI/mail thật

Port18084/3000/3002/11035/11036 phải trống. CORS process demo chỉ localhost3000/3001/3002; không wildcard, không mở DB raLAN/firewall. Dùng terminal riêng hoặc Start-Process -WindowStyle Hidden, ghi PID vào private registry và xác minh trước stop.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/account-integration-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
node frontend/serve-booking-web.mjs ad
node frontend/serve-booking-web.mjs member
node frontend/account-integration-mail-sink.mjs $private
# Playwright1.56.1 và installed Chrome; npm.cmd nếu PowerShell chặn npm.ps1:
# npm.cmd install --offline --no-audit --no-fund --prefix <private-tools-dir> playwright@1.56.1
# PGPASSWORD process-only từ app.dpapi; $playwright là index.mjs ngoài Git:
node frontend/verify-member-account-activation.mjs $private $playwright
```

Mail chỉ SMTP127.0.0.1:11035 và synthetic @example.invalid; inbox memory-only, protected control127.0.0.1:11036/key ngoài Git; OTP không stdout/disk/screenshot. Browser1024×768/timezone America/Los_Angeles. Harness tạo intent/UUID registry **trước** account POST, không replay write. Luồng thật: Admin Home→Hội viên&PT→Thêm Member DISABLED; Home→Kích hoạt Gói hội viên→thu quầy; Member Login→kích hoạt→email/OTP/password→ACTIVE→login→M04→reload/login. Xác minh noJWT trước ACTIVE, role-isolation PT, grant replay400, cùng UUID/date và snapshot Membership/payment/PT cũ không đổi.

Nếu UI lỗi, giữ member-ui-registry/results để đối chiếu; đã201 thì cleanup/reconcile đúngUUID trước fixture mới, không gửi lại với key mới mù. Harness từ chối ghi đè result/registry; archive riêng local sau cleanup, không xóa authority cũ. Không chỉnh Clock production hoặc seed ACTIVE Member để bỏ qua OTP.

## 4. Cleanup và dừng

```powershell
# Còn PGPASSWORD process và đúng resource manifest:
node frontend/cleanup-member-account-activation.mjs $private
node frontend/cleanup-member-account-activation.mjs $private
# Stop riêng backend/web/mail PID đã đối chiếu identity/port; sau đó:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/account-integration-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Cleanup seal exactUUID registry trước DELETE, child rows chỉ qua ownedMember/User, snapshot mọi row ngoài registry giữ nguyên. Không broad delete/TRUNCATE/DROP/history edits, giữ volume/schema. Dừng mail để xóa OTP memory; không dừng Docker Desktop/container ngoài task. Private registry/credentials/logs/tools/build không đưa Git.

Lượt này từng mất directory private của sandbox khi môi trường phiên đổi: chỉ sau khi xác minh fullID/label/image/volume/port/role/zero sessions và synthetic namespaces mới phục hồi UUID registry, xoay credential **riêng app test**, không sửa rows/history. Đây là recovery có kiểm chứng, không hướng dẫn reset resource hay dùng lại DB shared khi mất manifest.
