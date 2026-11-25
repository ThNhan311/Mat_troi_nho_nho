# M-05/M-06 — renewal/simulator quickstart riêng

> Hướng dẫn lịch sử tại commit `4af8bb8`. Với source hiện hành, dùng [portable setup Core](../INTEGRATION_SETUP.md) và `backend/scripts/core-readiness.ps1`; không áp candidate/authority cũ lên checkout mới. Các lệnh bên dưới được giữ để đọc evidence của task gốc.

[Contract/quyết định/khóa](decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md), [evidence/source hashes](evidence/M05_M06_RENEWAL_SIMULATOR.md). Base `d2774c9`; chỉ rehearsal, không DB chung/production. Đọc [I01 authority/release gate](20_CORE_INTEGRATION_QUICKSTART.md) trước. Không dùng core runner cũ trên branch có V11: inventory cũ cố ý từ chối file thêm.

## Guard và kiểm thử

JDK21, Docker Desktop local Linux engine, Node24, Flutter3.50.1/Dart3.14 theo lock, Chrome/Playwright1.56.1 ngoài Git. Không sửa PATH hệ thống. `$private` là thư mục Temp riêng bền, không trong Git/sandbox phiên; credentials/registry/logs giữ private. Chưa có container thì Provision; container cùng tên đã có phải đối chiếu authority/full64hexID/image/label/volume/loopback15441, không ghi đè. Khi tái dùng own container, private scope mới chỉ có runs task này; authority cũ giữ nguyên.

```powershell
node backend/scripts/renewal-migration-inventory.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/renewal-integration-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $private
# Hoặc start exact own container đã inspect và dùng manifest riêng đã xác minh.
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/renewal-integration-rehearsal.ps1 -Action Verify -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/renewal-integration-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Test tạo renewal empty/history pair mới và account integration pair riêng, không reset dữ liệu. Renewal history: V1–V6,V8–V10 + dữ liệu lịch sử tổng hợp, snapshot tất cả tables trước V11; V11 backfill additive giữ payment periods/status/null, M03 receipt/audit/snapshots và activation states. DB empty cũng migrate đầy đủ10scripts. Các account DB chưa được suite focused dùng vẫn trống; cleanup nhận diện rõ, không tự migrate chúng chỉ để cleanup.

`-FullSuite` cần baseline15437 password từ DPAPI vào DB_PASSWORD **process**, không literal secret. Selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`; integrated replacements vẫn chạy. Renewal và account dùng hai pair khác nhau đúng guard; Booking HTTP dùng baseline15437. Không gọi toàn bộ profiles đều chạy, không cộng focused vào full. Bài concurrency giữ khóa Member bên ngoài, chờ cả hai requests thật sự đợi PostgreSQL lock rồi nhả; rollback trigger tổng hợp chỉ trong test DB.

## Chạy Web và E2E thật

Sau tests và trước E2E, dừng own backend nếu có, tạo pair **mới** bằng NewRun. Không Test/NewRun trong lúc UI harness chạy. Package JDK21 và chuẩn bị classpath (quote JVM option trong PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/renewal-integration-rehearsal.ps1 -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
backend/mvnw.cmd -f backend/pom.xml -B -ntp package -DskipTests
backend/mvnw.cmd -f backend/pom.xml dependency:build-classpath "-Dmdep.outputFile=$private/classpath.txt"
# DB_PASSWORD process từ app.dpapi; nonce từ current-run.json, không in credential.
$classpath = 'backend/target/classes;' + [IO.File]::ReadAllText("$private/classpath.txt").Trim()
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/RenewalIntegrationDemo.java $private $nonce
```

Helper từ chối DB có tables, migrate đúng1–6,8–11 và chỉ seed Admin BCrypt. `demo-fixture.properties` CREATE_NEW chứa UUID/credential private; không overwrite. Mọi plan, Member chưa ACTIVE, initial Membership/payment tạo qua API; Member OTP/password và renewal/simulator qua UI thật. Không seed ACTIVE Member cho E2E này. Boundary/expired tests dùng test Clock, không đổi Clock production.

Tại từng app Member/Admin: `flutter test --reporter expanded`, `flutter analyze --no-fatal-infos`, `flutter build web --dart-define=API_BASE_URL=http://localhost:18084/api/v1`. Infos có sẵn được ghi riêng; không hạ SDK/dependencies. PT Dart không đổi trong task này nên không rerun PT Flutter để cộng số.

Kiểm port18084/3000/3002/11035/11036 trống; Start-Process hidden hoặc terminal riêng, ghi PID/starttime/command line private. Runner CORS chỉ localhost3000/3001/3002, không wildcard/LAN/firewall.

```powershell
node frontend/account-integration-mail-sink.mjs $private
node frontend/serve-booking-web.mjs member
node frontend/serve-booking-web.mjs ad
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/renewal-integration-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
# PGPASSWORD process từ app.dpapi; Playwright index.mjs ngoài Git.
node frontend/verify-renewal-integration.mjs $private $playwright
```

E2E Chrome1024×768/timezoneAmerica/Los_Angeles: chỉ seedAdmin → Admin login UI; plans/account/M03 qua HTTP thật; Member activate SMTP/UI → Membership gốc → tạo PENDING → Admin simulator SUCCESS → Member reload/login đọc CURRENT/NEXT/same UUID/giá0 → hai giao dịch mới FAILED/CANCELLED không cộng hạn → result replay/late conflict/ownership đối chiếu PostgreSQL. Không lấy callback/localstate làm SUCCESS. Header bearer/OTP/password không vào evidence; ảnh chỉ sau auth. Harness có intent registry trước writes, không chạy lại mù khi thất bại. Đối chiếu registry, cleanup, archive private attempt và tạo pair mới.

## Cleanup

```powershell
node frontend/cleanup-renewal-integration.mjs $private
node frontend/cleanup-renewal-integration.mjs $private
# Dừng PID có đúng starttime/command: own JVM + wrapper, hai web, mail.
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/renewal-integration-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Cleanup chỉ run trong task manifest, legacy fixtures/TSV/intent UUID đã đăng ký. Child UUID suy từ Member/payment thuộc fixture, seal ledger trước DELETE, snapshot ngoài ledger trước/sau. FK order events→event keys→quotes→paid periods→audit/receipt/payment→booking/slot/Membership/plan→activation/profile/User. SQL nhiều UUID qua stdin để tránh ENAMETOOLONG của Windows; mỗi DB trong một transaction. Unmigrated pair phải có0publictables. Giữ schema/history/volume. Nếu full đã start own baseline15437, inspect đúng resource/không session rồi stop riêng, không dừng tài nguyên người khác.

Release vẫn blocked: V7 database558fb03 DROP periods chưa backfill, shared history unknown, chưa đồng bộ thứ tự/semantics V7–V11. Không apply V7/out-of-order/clean/repair hoặc đưa rehearsal gap7 thành release. Simulator không tiền thật, chưa gateway/refund/production mail.
