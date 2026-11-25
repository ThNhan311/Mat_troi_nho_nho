# F02 — Enrollment rehearsal / Admin UI

> Hướng dẫn lịch sử tại commit `de82618`. Với source hiện hành, dùng [portable setup Core](../INTEGRATION_SETUP.md) và `backend/scripts/core-readiness.ps1`; không áp candidate/authority cũ lên checkout mới. Các lệnh bên dưới được giữ để đọc evidence của task gốc.

[Contract/khóa/saga](decisions/2026-11-24_F02_FACE_ENROLLMENT.md), [evidence](evidence/F02_FACE_ENROLLMENT.md). F02 là lifecycle **SIMULATED_TEST**, chưa camera/enrollment/recognition/liveness thật. Không gửi hoặc lưu ảnh/vector người thật.

## Guard và migration

JDK21/JVM UTC, Docker Desktop local Linux, Node24, Flutter3.50.1/Dart3.14 hiện có; không đổi PATH/dependencies app. `$private` là Temp riêng ngoài Git; authority account-resource.json + app.dpapi thuộc container test của chính task, **runs chỉ F02**. Không copy/reset credential hay registry công việc đồng đội. Fresh install dùng Provision khi không collision; tài nguyên đã có phải verify full containerID/image/label/volume/port và authority trước start, không Provision đè. Role fitcenter_account_app không đặc quyền, chỉ loopback15441; namespace fitcenter_account_<12hex>_(empty|history)_test. Baseline15437 chỉ full suites đã guard riêng.

```powershell
node backend/scripts/enrollment-migration-inventory.mjs
# Chỉ khi tạo tài nguyên mới không collision:
# powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $private
# NewRun tạo current-run trước Verify nếu authority chưa có current-run:
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action Verify -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
# Full cần DB_PASSWORD baseline process-only/DPAPI, không literal password:
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action Test -FullSuite -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Runner tạo **4pairs mới**, không reset: F02(13), account(10), renewal(11), F01(12); focused chỉ F02 nên pair khác có thể0publictables. Candidate1–6,8–13/12scripts, V7 quarantine; inventory cũ F01 cố ý từ chối SQL mới, không lách bằng sửa manifest lịch sử. Full selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`; các integrated counterparts chạy. Không chọn FitcenterApplicationTests vì pattern *Test, không dùng alignment profile. Lưu log/report/UUID ledgers private; stdout chỉ kết quả tổng hợp. Không in raw log có thể chứa nội dung nhạy cảm của framework.

## Admin app

Giữ source/theme/Home/navigation gốc; thêm menu Đăng ký khuôn mặt, chọn members.id từ Admin account list. Ba xác nhận Member/at-gym/consent bắt buộc. Start chỉ PENDING; Complete phải đọc status từ server, không coi HTTP200 là ACTIVE. Hủy PENDING hoặc Thu hồi profile có xác nhận. FAILED giữ mẫu cũ; cảnh báo cleanup khi pending/manual. Default Backend trả503, UI không mock fallback. Session memory/epoch/modal trong navigator phiên; logout xóa route/response cũ. Write timeout chỉ GET đối chiếu, không replay tự động; start giữ key, complete/pending revoke giữ operation ID, profile revoke giữ key khi chưa rõ.

```powershell
# SDK riêng đã xác minh, không thêm vào PATH hệ thống:
& $flutter analyze --no-pub --no-fatal-infos
& $flutter test --no-pub --machine
& $flutter build web --release --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:18086/api/v1
```

Analyze có109 info (deprecated Material/flow braces), 0error/0warning; không gọi zero issues. Member/PT Dart không thay đổi, không chạy lại Flutter của chúng. Web build JS đã chạy, không chứng minh mobile/camera.

## Demo riêng, UI + Core + DB thật / identity mô phỏng

Sau tests/package, tạo pair mới. Java helper từ chối DB có tables; migrate/verify12scripts, seed **chỉ synthetic Admin và2ACTIVE Member accounts**, không FacialProfile hoặc Membership/payment. ACTIVE account là fixture, không phải chứng minh Account activation. Keys và captures chỉ private, không Web bundle.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
backend/mvnw.cmd -f backend/pom.xml -B -ntp package -DskipTests
backend/mvnw.cmd -f backend/pom.xml dependency:build-classpath "-Dmdep.outputFile=$private/dependencies.txt"
$classpath = "$repo/backend/target/classes;" + [IO.File]::ReadAllText("$private/dependencies.txt").Trim()
# DB_PASSWORD process-only từ own app.dpapi; nonce từ current-run.json:
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/EnrollmentDemo.java $private $nonce
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
# Terminal/process khác, port3002 trống:
node frontend/serve-booking-web.mjs ad
# PGPASSWORD process-only; Playwright riêng ngoài Git + Chrome đã có:
node frontend/verify-face-enrollment.mjs $private $playwrightIndex
```

Backend18086 loopback, exact7Flywaylocations; CORS vẫn đúng localhost3000/3001/3002, không LAN/wildcard/firewall. Nếu background: Start-Process -WindowStyle Hidden và lưu PID/starttime/command private. Helper registry/config CREATE_NEW, không overwrite. Playwright1.65.1 cài riêng Temp bằng official npm registry/lock integrity, ignore-scripts, dùng Chrome hiện có; không dependency app.

Harness bootstrap plan/initial Membership qua API M01/M03 để kiểm paid Core. Mọi FacialProfile được tạo bởi thao tác UI: start→complete READY→re-enroll FAILED→replacement READY→revoke→reload/login readback. Out-of-process adapter journal **chỉ synthetic references**, không gallery biometric thật. Failure setting private server config dùng kiểm compensation, không public fake endpoint. Core sends registered kiosk credential/opaque capture, old capture/request bị chặn sau replacement/revoke. Non-Face business rows snapshot trước/sau enrollment phải bằng nhau. HTTP trực tiếp10checks tách UI10checks/DB6checks, không cộng vào1076 Backend hoặc133widget.

Nếu một UI attempt chưa rõ/fail, không chạy harness lại mù (CREATE_NEW sẽ chặn); đối chiếu registry/DB và cleanup đúng run, archive attempt private, tạo pair/config mới. Không sửa source rồi dùng ảnh cũ chứng minh source mới.

## Cleanup/stop

```powershell
# PGPASSWORD process-only, DB còn hoạt động; đợi cả hai lệnh xong:
node backend/scripts/cleanup-enrollment-integration.mjs $private
node backend/scripts/cleanup-enrollment-integration.mjs $private
# Stop đúng PID/starttime/command của own Backend JVM/wrapper và Admin web rồi:
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/enrollment-integration-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Cleanup seals exact registered UUID, suy child từ owned Member; thứ tự ledger→revocations→enrollments/outbox→period/event/receipt→Attendance/FacialProfile→Membership/account. SQLstdin tránh Windows command limit. So sánh mọi row ngoài registry; giữ schema/history/volume, không truncate/drop/reset/clean/repair. Private simulated journal/authority giữ để audit, không phải biometric/gallery production; sau cleanup không còn mapping DB để dùng cấp quyền. Không stop Docker Desktop/tài nguyên đồng đội. Release vẫn cần shared migration inventory, V7 backfill/ordering và adapter thật; không bật default.
