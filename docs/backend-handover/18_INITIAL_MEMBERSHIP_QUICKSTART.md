# M-03 — chạy lại Admin initial Membership

> Hướng dẫn lịch sử tại commit `5399c57`. Với source hiện hành, dùng [portable setup Core](../INTEGRATION_SETUP.md) và `backend/scripts/core-readiness.ps1`; không áp candidate/authority cũ lên checkout mới. Các lệnh bên dưới được giữ để đọc evidence của task gốc.

Chỉ DB test riêng. [Contract/quyết định](decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md), [evidence](evidence/M03_INITIAL_MEMBERSHIP.md). Default profile vẫn503 cho M-03; PT activation mặc địnhfalse. Không dùng DB rehearsal1–6,9 làm release, không apply V7/V8 để mở M-03.

## JDK21 / PostgreSQL

Từ repository root, `$JavaHome` là JDK21 đã xác minh, `$private` là thư mục Temp riêng ngoài Git (không dùng lại credential khác), `$verifiedId` là containerID64hex **đọc từ manifest sau Provision và đối chiếu docker inspect**, `$playwright` là Playwright index.mjs ngoài repo. Không sửa PATH/ExecutionPolicy hệ thống. Runner cần cached image baseline tồn tại và port15440/container/volume chưa collision khi Provision; không ghi đè credential/resource cũ.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/membership-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $private
# Sau khi inspect identity/container/volume/loopback:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/membership-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/membership-rehearsal.ps1 -Action Verify -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Verify cần current-run nên ở trên Test chạy trước Verify. Không dùng NewRun trong luồng demo này vì chưa migrate/seed fixture; Test áp1–6, seed legacy rồi9, kiểm data snapshot và lưu run-<nonce>-fixture.properties. Mỗi Test tạo2 DB mới không reset DB cũ. Nếu resource manifest đã có, không Provision lại: inspect ID/label/volume/loopback theo manifest rồi `docker --context desktop-linux start $verifiedId` nếu own container đang dừng, sau đó Test tạo run mới. App-role không superuser/createdb/createrole/replication/bypassrls. Guard trước Flyway chỉ nhận localhost15440/fitcenter_membership_<nonce>_(empty|history)_test vàlocation đúng. Giữ mọi private manifest nếu kiểm thử lỗi để cleanup.

Focused: InitialMembershipPostgresTest+InitialMembershipGuardTest. Full: cùng lệnh Test thêm `-FullSuite`; nạp credential baseline15437 vào **process DB_PASSWORD từ DPAPI**, không gõ literal/in ra. Guard baseline ExpectedContainerId trong script phải được inspect lại. Full loại đúng2 suite PT rehearsal opt-in, vẫn chạy PT unit/mail tests; không bật PT activation/migrateV8. Không gọi đây là mọi test mọi profile.

## Web demo từ UI gốc

Đặt JAVA_HOME/JavaHome và PATH chỉ trong process terminal JDK21 trước Maven, xác minh java -version. JAR: `backend/mvnw.cmd -f backend/pom.xml -DskipTests package`. Admin/Member dùng Flutter SDK tương thích lock hiện có; không pub upgrade. Từ từng project chạy `flutter analyze --no-fatal-infos`, `flutter test --reporter expanded`, `flutter build web --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:18083/api/v1`. Analyze còn style/Material infos đã công bố; không gọi strict lint clean.

Dùng current-run.history từ manifest sau Test. Nạp DB_URL của DB đó, DB_USERNAME=fitcenter_membership_app và DB_PASSWORD từ app.dpapi vào env process; classpath được `backend/mvnw.cmd -f backend/pom.xml dependency:build-classpath -Dmdep.outputFile=<đường-dẫn-Temp-tuyệt-đối>` tạo file ngoài Git, đọc nội dung vào $classpath. Không đưa classpath/cache/password vào repo. Seed Java source launcher dùng BCrypt thật:

```powershell
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/MembershipInitialDemo.java seed "$private/ui-fixture.properties" $baseFixture
# $baseFixture = run-<current nonce>-fixture.properties; không ghi đè manifest tồn tại.
# Terminal riêng, không public DB/LAN/firewall:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/membership-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
node frontend/serve-booking-web.mjs ad
node frontend/serve-booking-web.mjs member
# PGPASSWORD process-only từ app.dpapi; Chrome hiện có:
node frontend/verify-initial-membership-ui.mjs "$private/ui-fixture.properties" $playwright
```

Port18083/3002/3000 phải trống; CORS chỉ localhost3000,3002. Ghi PID từng process task tạo vào private registry khi launch; Start-Process -WindowStyle Hidden. Default backend/production Clock không đổi. UI fixture gồm ACTIVE+DISABLED Member và ACTIVE plan30ngày/giá0; User ACTIVE là seed tổng hợp, **không MEMBER activation**. Chứng từ Membership/payment được tạo bằng Admin UI thật, không seed success. Admin Home→Kích hoạt Gói hội viên, chọn Member/plan, nhập chứng từ/xác nhận, reload/login/đọc snapshot; Member Home→Gói hội viên đọc M-04 cùng UUID/date. Chứng từ trùng của Member khác409 không fake success. Browser timezone America/Los_Angeles để kiểm ngày VN độc lập máy.

Harness từ chối ghi đè m03-ui-before/results. Nếu công cụ lỗi sauPOST201, giữ registry/kết quả để đối chiếu hoặc cleanup exact UUID trước fixture mới; không gửi lại với key khác mù. Credentials chỉ bàn giao local, không screenshot login fields/token.

## Cleanup và dừng

```powershell
# PGPASSWORD process chỉ app-role; verify context/container/volume/DB/history từ private manifest:
node frontend/cleanup-initial-membership-demo.mjs $private
# Chạy lại idempotent nếu cần kiểm; không cộng kiểm tra trùng:
node frontend/cleanup-initial-membership-demo.mjs $private
# Đóng flag seeded theo UI registry, env DB_URL/USERNAME/PASSWORD của current history:
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/MembershipInitialDemo.java cleanup "$private/ui-fixture.properties"
# Stop riêng backend/web PID đã đối chiếu commandline/port, rồi:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/membership-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Cleanup đọc baseUUID/testUUID/UIUUID, phục hồi registry cho namespace test bị cleanup lỗi trong chính DB task mới tạo, seal cleanup-<nonce>-<kind>.json **trước delete**. Chỉ DELETE từng UUID; snapshot rows ngoài registry giữ nguyên. Không DROP/TRUNCATE/reset, giữ schema/history/volume. Không stop Docker Desktop hoặc container ngoài task. Lần chạy tiếp theo dùng Test tạo DB mới; các DB đã migration không được coi là empty baseline.
