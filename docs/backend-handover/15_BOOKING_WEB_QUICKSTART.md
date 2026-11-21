# Quickstart — Booking Member/PT trên Flutter Web

Lát cắt: login → PT tạo slot90phút → Member đọc PT/slot, đặt auto-confirm → tải lại lịch hai bên. Backend base089b5e2; Frontend source0307242; nhánh feature/frontend-booking-integration. [Kết quả](evidence/BOOKING_WEB_INTEGRATION.md), [khảo sát](evidence/FRONTEND_INTEGRATION_SURVEY.md).

## Source và SDK

Làm từ worktree tích hợp. Hai project: [Member](../../frontend/fitcenter_member), [PT](../../frontend/fitcenter_pt). Production Backend/V1–V6 giữ nguyên; không alignment/V7. Prototype Membership/Payment/Workout nhập theo source gốc vẫn ngoài entry point Booking mới, không được nối API trong task này.

Đã xác minh Flutter3.50.1/Dart3.14.0, tương thích Dart^3.13.5. SDK riêng, không đổi PATH hệ thống. Nguồn chính thức: [archive](https://docs.flutter.dev/install/archive), [Windows manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json), [bundle3.50.1](https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.50.1-stable.zip). SHA256:
33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb.

Giữ nguyên pubspec constraints. Chỉ pub get, không pub upgrade: SDK mới buộc lock đổi meta1.18.3→1.19.0, test_api0.7.12→0.7.14, vector_math2.4.0→2.4.4 và thêm listen1.0.1. Không nâng hàng loạt package ứng dụng.

~~~powershell
$flutter = '<absolute-sdk-directory>\bin\flutter.bat'
& $flutter --version
& $flutter doctor -v
& $flutter devices
# Từ từng project:
& $flutter pub get --enforce-lockfile
& $flutter analyze --no-fatal-infos
& $flutter test --reporter expanded
& $flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1
~~~

Analyzer còn infos deprecation Material từ SDK mới và vài infos legacy; không error/warning. --no-fatal-infos không bỏ qua errors/warnings. Web JavaScript đã build/chạy; chưa build Wasm/native. Doctor xác nhận Chrome/Edge; thiếu Android SDK/C++ desktop workload không chặn Web.

## Backend và fixture riêng

Cần JDK21 và Docker Desktop local Linux engine với PostgreSQL test V1–V6. Từ repository root, không dùng [start-local](../../backend/scripts/start-local.ps1) mặc định alignment.

Tài nguyên đã dùng: container fitcenter-baseline-20261120-db; label fitcenter.task=baseline-20261120; volume fitcenter_baseline_20261120_data; loopback127.0.0.1:15437→5432; DB fitcenter_baseline_20261120_test; app role fitcenter_baseline_app. Xác minh lại full container ID/label/mount/port/context. [Guarded CLI](../../backend/scripts/booking-demo.ps1) kiểm JDK/datasource/privileges/history và canonical migrations trước Spring/Flyway. Jar phải chứa đúng6 file V1–V6 có hash khớp source, không V7/stale migration.

~~~powershell
$JavaHome = '<absolute-jdk-21-directory>'
$privateDir = Join-Path $env:LOCALAPPDATA 'Temp\fitcenter-booking-demo-private'
New-Item -ItemType Directory -Force -Path $privateDir | Out-Null
$manifest = Join-Path $privateDir 'fixture.properties'
$verifiedId = '<verified-64-character-container-id>'
$env:JAVA_HOME = $JavaHome
$env:PATH = "$JavaHome\bin;$env:PATH"
Push-Location backend
.\mvnw.cmd -B -ntp -DskipTests package
.\mvnw.cmd -B -ntp dependency:build-classpath "-Dmdep.outputFile=$privateDir\classpath.txt"
Pop-Location
# SecureString prompt nếu chưa có DB_PASSWORD. Bypass chỉ PowerShell con.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Seed -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest -StartDatabase
~~~

Manifest ngoài Git trong Temp riêng chứa UUID/credentials tổng hợp để bàn giao local; không đưa nội dung lên log/issue/báo cáo. BCrypt dùng BCryptPasswordEncoder thật. Seed tạo ADMIN, MemberA/B+profile, PTA/B+profile, plan/membership ACTIVE theo DATE Việt Nam bao phủ session; không booking giả cho luồng UI. Seed lặp không thay row khi seeded=true. Không dùng AutoCloseable fixture đã cleanup của Maven làm tài khoản demo; không endpoint test mới.

Cấp DB password role test qua SecureString prompt hoặc env process rồi xóa/khôi phục sau chạy. Runner không tự đổi DB password. Nếu mất, quản trị đúng DB test cấp lại; không sửa tài nguyên dùng chung. Phiên nghiệm thu dùng credential test tạm mã hóa DPAPI local.

Terminal Backend riêng:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action ServeBackend -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest -BackendPort 18081
~~~

Port18081 phải trống. Backend bind127.0.0.1, JVM UTC, profile default, JWT key trong memory; CORS chỉ http://localhost:3000 và http://localhost:3001. Không wildcard/mở DB ra LAN. Backend restart làm token cũ hết hiệu lực; login lại.

Terminal khác, thiết lập policy đầu tiên bằng Admin PUT thật:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Policy -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
~~~

Policy fixture14/2/4/5; effectiveFrom do server đặt. Admin credential/token chỉ ở tool setup trong memory, không cấp cho app Member/PT. Seed từ chối policy có sẵn ngoài fixture.

## Chạy Web và đối chiếu

Từ repository root, hai terminal:

~~~powershell
node frontend/serve-booking-web.mjs member
node frontend/serve-booking-web.mjs pt
~~~

Mở http://localhost:3000 cho Member, http://localhost:3001 cho PT. [Static server](../../frontend/serve-booking-web.mjs) chỉ phục vụ build/web trên loopback, không thư mục credential. API_BASE_URL qua dart-define; thay URL cần build lại. Không hardcode8080/emulator.

1. Login PTA → nhập bắt đầu YYYY-MM-DD HH:mm giờ Việt Nam, chọn slot tương lai phù hợp policy, ví dụ ngày mai10:00. End=start+90phút; sau201 UI dùng UUID/time/status thật và reload slots.
2. Login MemberA → chọn PT profile UUID từ catalog → detail/available → chọn slot và đặt. Chỉ sau201 mới báo CONFIRMED; available/lịch được reload.
3. PT Tải lại dữ liệu: cùng booking UUID/time, slot BOOKED; Member available không còn slot đã đặt. Giờ UTC+07:00 độc lập timezone máy.
4. Reload cần login lại, booking vẫn từ server. MemberB không thấy bookingA; PTB không thấy bookingPTA. PT dùng member UUID rút gọn, không bịa tên/rating/số buổi.
5. Session chỉ memory; logout xóa session. GET401 refresh tối đa một lần rồi retry GET một lần. POST401 có thể refresh nhưng không gửi lại POST. Lỗi mạng/timeout/5xx hoặc write response chưa chắc chắn không báo thành công/không retry mù; khóa gửi tới khi người dùng reload đối chiếu. Kiểm tra lịch/slot trước thao tác mới.
6. 409 hiển thị error.code/correlationId, bỏ selection và reload. Không fallback mock/approval/PENDING/REJECTED. Chưa nối PATCH/DELETE/cancel/complete/eligibility, Admin UI hoặc tính năng ngoài slice.

Khoảng xem now−1ngày tới now+31ngày, hiển thị trên UI; chưa range picker. from/to UTC ISO cóZ, encode bằng Uri queryParameters. Không dùng API Admin để cấp policy cho Member/PT; public policy contract vẫn là task riêng.

## Probe HTTP và cleanup

~~~powershell
$bookingId = '<booking-uuid-from-ui>'
node frontend/verify-booking-demo.mjs verify $manifest $bookingId
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Audit -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
~~~

[Probe HTTP](../../frontend/verify-booking-demo.mjs) kiểm login/role/CORS/401/403, DTO/ownership, cùng UUID/time và BOOKED/available. Đây là HTTP checks, không widget/UI automation. Để tái lập409: MemberA chọn slot, chạy node frontend/verify-booking-demo.mjs claim $manifest '<slot-uuid>' để MemberB lấy slot, rồi MemberA bấm đặt.

~~~powershell
# Đăng ký UUID mới sau thao tác UI/API:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Capture -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
# Logout app, dừng đúng static servers/Backend phiên demo. DB còn chạy để cleanup:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action Cleanup -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
~~~

Cleanup DELETE từng UUID, FK-order trong transaction. Capture chỉ đăng ký rows thuộc PT/member fixture; dừng nếu thấy ownership ngoài fixture. Không truncate/broad delete/reset DB. Giữ manifest để seed lại. Rotate chỉ đổi đúng credentials actor fixture, lưu riêng local, không in giá trị.

Cuối cùng dừng đúng container đã xác minh nếu phiên này tự khởi động, giữ volume; không stop container/engine phục vụ người khác. Trạng thái sau nghiệm thu ở [báo cáo](evidence/BOOKING_WEB_INTEGRATION.md).
