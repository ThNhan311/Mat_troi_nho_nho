# PT activation rehearsal riêng — Windows/JDK21

> Hướng dẫn lịch sử tại commit `0c31947`. Với source hiện hành, dùng [portable setup Core](../INTEGRATION_SETUP.md) và `backend/scripts/core-readiness.ps1`; không áp candidate/authority cũ lên checkout mới. Các lệnh bên dưới được giữ để đọc evidence của task gốc.

[Quyết định/version](decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md), [evidence](evidence/PT_ACTIVATION_POSTGRES.md). Đây là tooling cho DB test riêng, không bootstrap production hoặc DB chung. Không sửa V1–V6, không áp V7, không clean/repair/out-of-order. Default app không bật activation.

## Provision và tests

Dùng JDK21 đã xác minh; `$JavaHome` trỏ JDK, `$PrivateDirectory` là thư mục Temp riêng ngoài repo. Không sửa PATH hệ thống. Runner dùng Docker desktop-linux local engine, image cache từ container baseline đã có; collision resource/port phải inspect, không ghi đè.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/activation-rehearsal.ps1 -Action Provision -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory
# Inspect full ID/label/image/volume/loopback15439 rồi gán $ContainerId.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/activation-rehearsal.ps1 -Action Test -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ContainerId
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/activation-rehearsal.ps1 -Action Verify -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ContainerId
# FullSuite cần DB_PASSWORD của baseline role riêng đã xác minh, chỉ process/secure prompt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/activation-rehearsal.ps1 -Action Test -FullSuite -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ContainerId
```

Provision chỉ một lần nếu chưa có tài nguyên, không overwrite manifest/credentials. Mỗi Test tạo cặp DB empty/history mới và ghi vào resource registry; không chạy lại trên DB đã migrate bằng cách clean. Verify/ServeBackend dùng current-run.json do Test/NewRun tạo; sau Provision cần Test hoặc NewRun trước Verify. Password DB private dùng DPAPI, không đưa lên Git hoặc lệnh/report. JVMUTC để tránh alias timezone máy; PostgreSQL/JDBC không cần nhận Asia/Saigon. Các test boundary dùng Clock test, không đổi production Clock.

Focused: schema10+HTTP20+guard9+OTPunit23+SMTPunit3. Full giữ baseline V1–V6 qua runner cũ và bật thêm activation suite trên hai DB mới. Runner từ chối nếu canonical khác sáu file baseline hoặc JAR có migration sai location/checksum. Không bật inherited Spring/Flyway/Maven override tùy ý.

## UI thật qua SMTP test

Sau Test pass, package Backend bằng JDK21 (`mvnw.cmd -B -ntp -DskipTests package`). Build Admin/PT, không hạ constraints hoặc đổi dependency:

```text
flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:18082/api/v1
```

Chạy trong từng app Admin/PT, rồi mở các process sau từ repo root. Nếu chạy background trên Windows, dùng Start-Process -WindowStyle Hidden, lưu PID private và kiểm commandline/parent trước stop.

```powershell
node frontend/activation-mail-sink.mjs $PrivateDirectory
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/activation-rehearsal.ps1 -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ContainerId
node frontend/serve-booking-web.mjs ad
node frontend/serve-booking-web.mjs pt
# PGPASSWORD nạp từ app.dpapi vào process duy nhất cho DB helper, xóa env sau khi dùng.
node frontend/verify-activation-rehearsal-db.mjs $PrivateDirectory prepare
node frontend/verify-pt-activation-e2e.mjs $PrivateDirectory $PlaywrightIndexPath
node frontend/verify-activation-rehearsal-db.mjs $PrivateDirectory audit
```

Backend127.0.0.1:18082; CORS chính xác localhost3001/3002. SMTP11025/control11026 chỉ loopback; control cần key private, không CORS/public API. OTP/mailbody chỉ memory; helper lấy mail và nhập UI tự động, không in code. Chỉ recipient @example.invalid. Không thêm API Backend để đọc OTP. Login/Admin/PT credentials trong run-<nonce>-fixture.properties riêng local, không tài khoản demo cũ đã cleanup.

UI helper chỉ một create intent, kết quả registry private CREATE_NEW; không replay khi timeout/mất mạng hoặc xóa registry để gửi lại. Đọc UUID/status rồi audit/cleanup trước khi archive attempt. Screenshots chụp trước nhập OTP/password hoặc sau khi clear, không chụp credential form đăng nhập. Email tổng hợp và UUID được phép trong evidence; không người thật/token/OTP/password.

## Cleanup

```powershell
node frontend/verify-activation-rehearsal-db.mjs $PrivateDirectory cleanup
node frontend/verify-activation-rehearsal-db.mjs $PrivateDirectory cleanup
node frontend/verify-activation-rehearsal-db.mjs $PrivateDirectory fixtures-cleanup
node frontend/verify-activation-rehearsal-db.mjs $PrivateDirectory fixtures-cleanup
# Sau đó stop đúng PID đã tạo; không kill theo tên rộng.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/activation-rehearsal.ps1 -Action Stop -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ContainerId
```

Cleanup theo chính xác User/profile/audit/activation/fixture IDs, transaction/FK giữ dữ liệu ngoài registry; chạy lại no-op. Không delete theo email/tên, truncate, drop DB hoặc Flyway clean. Giữ volume và database history để review; registry liệt kê từng run. Kiểm ports/process/container đã dừng; không stop engine hoặc tài nguyên ngoài task.

## Trước merge/release

V8 hiện ở database/activation-rehearsal, không canonical. Duy cần đồng bộ version/path/checksum và thứ tự với V7. DB rehearsal đã có8 sẽ từ chối7 đến sau; không sửa history/out-of-order để lách. Rehearsal release trên DB mới với chuỗi đã chốt, xử lý backfill/payment-period semantics của V7 riêng trước khi bật production. Đạt E2E test hiện tại không đồng nghĩa production mail hoặc toàn bộ FitCenter đã hoàn thành.
