# FitCenter

Quản lý phòng gym: backend Spring Boot và ba app Flutter Web. Bản demo chạy trên máy cá nhân.

| App | Thư mục | Địa chỉ |
|---|---|---|
| Hội viên | `frontend/fitcenter_member` | http://localhost:3000 |
| PT | `frontend/fitcenter_pt` | http://localhost:3001 |
| Admin | `frontend/fitcenter_ad` | http://localhost:3002 |

## Cần cài

Windows, JDK 21, Flutter, Node.js, Git, Docker Desktop (để chạy database).

## Cách chạy

Chạy trong PowerShell tại thư mục gốc. Thư mục `$private` chứa mật khẩu tự sinh: để ngoài Git và đừng xóa.

**1. Khai báo**

```powershell
$jdk = Read-Host 'Thu muc JDK21'
$private = Join-Path $env:LOCALAPPDATA ('Temp/fitcenter-core-' + [guid]::NewGuid().ToString('N'))
$runner = 'backend/scripts/core-readiness.ps1'
git fetch origin
```

**2. Tạo database, build backend, tạo tài khoản Admin**

```powershell
powershell.exe -ExecutionPolicy Bypass -File $runner -Action Provision -JavaHome $jdk -PrivateDirectory $private
$id = (Get-Content "$private/account-resource.json" -Raw | ConvertFrom-Json).containerId
powershell.exe -ExecutionPolicy Bypass -File $runner -Action Build -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
powershell.exe -ExecutionPolicy Bypass -File $runner -Action PrepareDemo -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
```

Email và mật khẩu Admin nằm trong `$private\demo-core\demo-fixture.properties`.

**3. Chạy backend** (cổng 18086, giữ cửa sổ này mở)

```powershell
powershell.exe -ExecutionPolicy Bypass -File $runner -Action ServeBackend -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
```

**4. Build ba app** (cửa sổ khác)

```powershell
foreach ($app in 'member','pt','ad') {
  Push-Location "frontend/fitcenter_$app"
  flutter pub get
  flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:18086/api/v1 --dart-define=KEEP_SESSION_ON_RELOAD=true
  Pop-Location
}
```

**5. Chạy web** (mỗi lệnh một cửa sổ)

```powershell
node frontend/serve-booking-web.mjs member
```

```powershell
node frontend/serve-booking-web.mjs pt
```

```powershell
node frontend/serve-booking-web.mjs ad
```

Mở bằng `localhost`, không dùng `127.0.0.1`.

## Gửi OTP qua mail thật

Đặt trước khi chạy backend, không ghi vào file trong repo: `FITCENTER_MAIL_SMTP_ENABLED=true`, `FITCENTER_SMTP_USER`, `FITCENTER_SMTP_APP_PASSWORD` (Gmail App Password).

## Lưu ý

- Thanh toán là **giả lập** (FitBank và mã QR không có thật).
- Check-in khuôn mặt mặc định **tắt** và chưa chống được ảnh giả.
- Số điện thoại và giới tính của PT lưu trong thư mục `.fitcenter` của người dùng, không nằm trong database.
- Các bước trên chưa được chạy thử trên máy mới. Gặp lỗi, xem [hướng dẫn chi tiết](docs/INTEGRATION_SETUP.md).

Tài liệu khác: [trạng thái](docs/PROJECT_STATUS.md) · [quyết định](docs/DECISIONS.md) · [API](docs/backend-handover/05_API_DOCUMENTATION.md)
