# F-01 — Core check-in rehearsal (simulated identity)

[Contract/khóa/schema](decisions/2026-11-24_F01_CHECKIN_CORE.md), [Face source survey](evidence/F01_FACE_SOURCE_SURVEY.md), [evidence](evidence/F01_CHECKIN_CORE.md). Base4af8bb8; Core test không phải Face ID E2E. Không camera/model/liveness/biometric thật. Không DB chung, không áp V7 destructive.

## Công cụ/authority

JDK21, Docker Desktop local Linux, Node24, Python3.12/pytest8.4.2 có sẵn. Không thêm dependency/đổi PATH hệ thống hoặc venv Face gốc. `$private` là Temp riêng bền ngoài Git/sandbox phiên. Tái dùng container riêng chỉ khi fullID/image/label/volume/loopback15441/app role khớp authority cũ; tạo private scope mới với **runs chỉ task F01**, giữ manifest cũ nguyên vẹn. Không Provision đè container hoặc credential. Chưa có tài nguyên thì Provision, đã có thì inspect/start exact ID trước Verify.

```powershell
node backend/scripts/checkin-migration-inventory.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/checkin-integration-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $private
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/checkin-integration-rehearsal.ps1 -Action Verify -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/checkin-integration-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Runner creates **3pairs**, không reset DB: F01 empty/history V1–V6,V8–V12; integrated account pair1–6,8–10; renewal pair1–6,8–11. Focused chỉ CheckinPostgresTest/CheckinUnitTest, nên hai pair còn lại có thể chưa migrate và cleanup xác minh0tables. F01 upgrade history có legacy6payments/periods/status/null, M03 receipt/audit/snapshot/activation state, V11paidperiods, synthetic V3facial/attendance; V12 snapshots tất cả rows cũ bằng nhau. Request UUID registry TSV/private properties được tạo trước hoặc ngay khi nhận UUID, không vào Git.

`-FullSuite` cần baseline15437 password DPAPI vào DB_PASSWORD **process**, không literal secret. Selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`, integrated counterparts được chạy; Booking/default HTTP ở baseline15437, account/renewal/F01 ở3pairs khác nhau15441. Không dùng runner inventory cũ khi checkout có V12; frozen old runner cố ý từ chối migrations mới. Không cộng focused vào full.

## Python addon/prototype tests

Source thực tế: Face pinfcabeba, source kiosk tìm thấy0307242 còn mock. Export đúng `face/prototype`, `face/tests`, `face/__init__.py`, config/pytest từ Face pin vào `$private/face-source`, không checkout đè Face untracked. Kiểm source hashes/provenance. Không tải/chạy InsightFace, không enroll người thật.

```powershell
$env:PYTHONPATH = "$private/face-source"
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:PYTHONIOENCODING = 'utf-8'
& $python -m pytest -q -p no:cacheprovider face/integration/tests "$private/face-source/face/tests/test_state_machine.py" "$private/face-source/face/tests/test_auth_flow.py" "--junitxml=$private/python-tests.xml"
```

Dùng venv Python hiện có chỉ đọc hoặc venv riêng, không pip install/update venv Face gốc. Addon tests tự opt-in bằng monkeypatch; không đổi mode mặc định của prototype. Không chọn detector/selector/embedding/gallery/service suites ở lượt này; không ghi chúng skipped0 như đã chạy. [Wiring hẹp](../../face/integration/README.md) dùng existing SingleFlightWorker/PrototypeController, không tự sửa app.py/Flutter main.

## Core E2E — backend thật, identity mô phỏng

Sau Test kết thúc, dừng own backend trước khi đổi current-run; NewRun pair mới, không dùng DB history có fixtures tests. Package JDK21 từ source đã test; classpath chỉ private. Quote JVM flag trong PowerShell.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/checkin-integration-rehearsal.ps1 -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
backend/mvnw.cmd -f backend/pom.xml -B -ntp package -DskipTests
backend/mvnw.cmd -f backend/pom.xml dependency:build-classpath "-Dmdep.outputFile=$private/dependencies.txt"
# DB_PASSWORD process từ app.dpapi; nonce từ current-run.json.
$classpath = 'backend/target/classes;' + [IO.File]::ReadAllText("$private/dependencies.txt").Trim()
& "$JavaHome/bin/java.exe" '-Duser.timezone=UTC' -cp $classpath backend/scripts/CheckinDemo.java $private $nonce
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/checkin-integration-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Helper từ chối DB có tables, verify datasource/role rồi migrate11scripts trên pair mới. Chỉ seed synthetic Admin/2ACTIVE Member accounts/profiles + synthetic facial references; **không phải triển khai Account activation/enrollment Face**. Không seed Membership/payment; harness tạo plan và thu quầy/Membership bằng API thật. Private fixture properties/config CREATE_NEW trước INSERT, không overwrite. Schema V3 source chỉ FACE nên ledger/history verificationMode ghi SIMULATED_TEST rõ; không giả liveness.

ServeBackend guard exact6locations, flags và container/volume/DB. Port18085 phải trống, server127.0.0.1; CORS giữ đúng localhost3000/3001/3002, không wildcard/LAN/firewall. Default flags tắt/503. Không cần mở GUI, mail sink hoặc camera trong Core E2E này. Nếu chạy background dùng Start-Process -WindowStyle Hidden, lưu PID/starttime/command private.

Tại terminal khác, PGPASSWORD process từ app.dpapi:

```powershell
$env:FITCENTER_CORE_CHECKIN_TEST_ADAPTER_ENABLED = 'true'
& $python backend/scripts/verify-checkin-core.py $private
```

Harness validates DB history/role/container before data, private intent/request ledger before writes. Actual CoreCheckinClient/SingleFlightWorker sends realHTTP: first Attendance→kiosk khác duplicate→same request replay→no-match/unknown→401public/Member/Admin claim→409reuse→owner history/fresh login. DB checks UUID/time and no mutation outside Attendance/ledger. Không đổi Clock production hoặc chờ30phút; boundary30m/DATE/renewal expiry và lock waiting dùng Java tests. Nếu fail: reconcile registry/DB, không chạy harness lại mù hoặc tạo key mới để đoán success; cleanup exactUUID, archive private attempt, tạo run mới.

## Cleanup/stop

```powershell
node backend/scripts/cleanup-checkin-integration.mjs $private
node backend/scripts/cleanup-checkin-integration.mjs $private
# Đợi cả hai lệnh hoàn tất thành công rồi mới stop own PID/starttime/command (JVM + wrapper).
powershell -NoProfile -ExecutionPolicy Bypass -File backend/scripts/checkin-integration-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $verifiedId
```

Cleanup chỉ run task manifest/registered UUID, suy child từ owned Member/payment, seal ledger trước DELETE. Order checkin_requests→renewal events/keys/quotes/paid periods→audit/receipt/payment→bookings/slots/Attendance/facial profiles→Membership/plan/activation/profile/User. SQLstdin tránh Windows command-length; snapshot rows ngoài ledger không đổi, giữ schema/history/volume. Baseline15437 do full runner start phải được dừng đúng authority nếu không còn session; không stop tài nguyên đồng đội/Docker Desktop. Private credentials/config/logs/export/build ngoài Git.

ReleaseReady=false: cần shared history/inventory, an toàn V7 backfill/mapping và đồng bộ V8–V12. V12 ledger hiện đóng ở SIMULATED_TEST; production Face attestation/liveness/capture/enrollment/retention chưa được duyệt/kiểm chứng. Không out-of-order/clean/repair/history edit/renumber hoặc bật default để lách.
