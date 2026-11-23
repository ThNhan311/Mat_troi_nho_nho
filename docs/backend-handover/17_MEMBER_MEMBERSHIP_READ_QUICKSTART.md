# M-04 — chạy Member Membership Web

Dùng [quickstart Booking](15_BOOKING_WEB_QUICKSTART.md) cho JDK21, cached dependency classpath, Flutter3.50.1/Dart3.14.0 và guard DB baseline. Không activation-rehearsal/alignment, không áp migration mới. Backend không đổi nên không cần lặp full Backend chỉ để chạy Dart. Kiểm JAR dùng canonical V1–V6, default profile activation=false. Không sử dụng DB chung.

## Kiểm tra Flutter

Từ `frontend/fitcenter_member`, `$flutter` là SDK riêng, không sửa PATH hệ thống. PUB_CACHE riêng ngoài Git. Không pub upgrade hoặc hạ constraints.

```powershell
& $flutter analyze --no-fatal-infos
& $flutter test test/membership_test.dart --reporter expanded
& $flutter test --reporter expanded
& $flutter build web --dart-define=API_BASE_URL=http://localhost:18081/api/v1
```

Analyze đang có informational Material deprecation/style; xem evidence, không bỏ qua errors/warnings. Focused là tập con full. Chỉ Member thay đổi; không cần Admin/PT hoặc full Backend nếu source không đổi.

## DB fixture riêng và UI thật

Chọn thư mục Temp mới cho `$manifest` (fixture.properties), copy cached `classpath.txt` vào cùng thư mục; **không copy/ghi đè credential fixture cũ**. `$JavaHome` là JDK21, `$verifiedId` phải khớp container test baseline đã inspect; `$playwright` là đường dẫn index.mjs của Playwright riêng ngoài repo. Dùng Chrome hiện có. Port3000/18081 phải trống. Secret DB chỉ env process/SecureString, không gõ vào command/history hoặc docs.

Từ repository root, dùng PowerShell con ExecutionPolicy Bypass nếu policy máy chặn script; không đổi policy hệ thống:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Seed -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest -StartDatabase
# Terminal riêng: default profile, chỉ CORS localhost3000/3001, không cần Admin web
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action ServeBackend -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest -BackendPort 18081
# Terminal riêng:
node frontend/serve-booking-web.mjs member
# Process PGPASSWORD đã nạp an toàn bằng credential local, không in:
node frontend/verify-member-membership.mjs $manifest $playwright run
```

[Runner](../../frontend/verify-member-membership.mjs) guard Docker desktop-linux/container/volume/loopback15437/DB role/history1–6. `run` tạo m04-registry.json bằng wx trước mutation; từ chối ghi đè evidence/cleanup authority. Tài khoản demo tổng hợp MEMBER ACTIVE do seed, không phải MEMBER activation. UI login→tab Gói hội viên, tải lại/login lại; kiểm array UUID/date/status với PostgreSQL, ownerA/B, empty/multiple và5status+ngày biên. SQL fixture trực tiếp tạo scenario, UI chỉ đọc. Login credentials trong local fixture.properties không đưa Git/báo cáo. Không cần tạo booking/policy/payment hoặc gửi mail.

Nếu công cụ/UI lỗi, cleanup vẫn bằng registry hiện tại; giữ manifest cũ cho cleanup, không chạy run chồng lên registry. Sau cleanup thành công, lưu lại registry/result ngoài Git với tên riêng hoặc dùng manifest/run directory mới cho lần tiếp theo. Không xóa dữ liệu khác để làm bài test xanh.

```powershell
# Phải cleanup scenario trước base fixture; vẫn cần PGPASSWORD process:
node frontend/verify-member-membership.mjs $manifest $playwright cleanup
# Chạy lại cleanup an toàn trước base cleanup nếu muốn kiểm:
node frontend/verify-member-membership.mjs $manifest $playwright cleanup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Cleanup -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
```

Scenario cleanup exact UUID+profile+plan, rollback nếu FK chặn; restore original rows/snapshot, không broad delete. Sau base cleanup, không chạy scenario cleanup để tái chèn rows (chặn bởi seeded=false). Dừng đúng PID/backend/web và container tự khởi động, giữ volume; đừng tắt Docker Desktop nếu còn containers ngoài task. Không gửi passwords/tokens/logs/private registry vào Git. Runner chụp ảnh1024×768 trong thư mục evidence; ảnh không có credentials. [Kết quả/hashes/giới hạn](evidence/M04_MEMBER_MEMBERSHIP.md).
