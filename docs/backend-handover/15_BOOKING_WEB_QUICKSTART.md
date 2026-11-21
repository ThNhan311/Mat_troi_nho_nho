# Quickstart — Booking Member/PT trên Flutter Web

Lát cắt đầu login → PT tạo slot → Member đặt và lịch hai bên đã đóng bằng commit9fe34b9. Nhánh hiện tại feature/frontend-booking-lifecycle bổ sung hủy, sửa/loại availability, kiểm tra điều kiện và complete; Backend base089b5e2, Frontend nguồn0307242. [Kết quả](evidence/BOOKING_WEB_INTEGRATION.md), [khảo sát](evidence/FRONTEND_INTEGRATION_SURVEY.md).

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
6. 409 hiển thị error.code/correlationId, bỏ selection và reload. Không fallback mock/approval/PENDING/REJECTED. Đã nối PATCH/DELETE/cancel/complete/eligibility theo phần lifecycle bên dưới. Admin UI và tính năng ngoài slice vẫn chưa tích hợp.

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

## Booking lifecycle trên Web

[Báo cáo và bằng chứng mới](evidence/BOOKING_WEB_LIFECYCLE.md), [hashes source được test](evidence/BOOKING_WEB_LIFECYCLE_HASHES.json). Giữ SDK/JDK/datasource/guarded runner/2origin như trên. Không cần build lại Backend chỉ vì đổi Dart; jar đã có các API Backend R02/R04/D01. Dart đổi phải test/build lại hai app.

| Ứng dụng / nút | API | Xử lý |
|---|---|---|
| Member Hủy booking | POST /bookings/{booking.id}/cancel | Xác nhận,200 DTO rồi reload lịch/available; deadline do policy server, thiếu policy/409 không đổi state giả |
| PT Sửa slot | PATCH /pt/availability/{slot.id} | Input giờ Việt Nam,+90phút; dùng UUID trong response kể cả UUID thay thế, reload |
| PT Loại slot | DELETE /pt/availability/{slot.id} | Xác nhận,204 rỗng không decode JSON; giữ row DISABLED/history |
| PT Hủy session | POST /pt/bookings/{booking.id}/cancel | Reason bắt buộc; server kiểm now<startAt;200 DTO và reload |
| PT Kiểm tra điều kiện | GET /pt/bookings/{booking.id}/service-eligibility | Đọc eligible/reasonCodes/checkedAt kể cả HTTP200false; mỗi lần bấm là GET mới, đóng dialog bỏ kết quả |
| PT Hoàn tất | POST /pt/bookings/{booking.id}/complete | Xác nhận; server quyết định now>=endAt,200 DTO; không bắt buộc GET eligibility trước |

Nút write khóa khi đang gửi, kể cả đang xác nhận/dialog. BOOKED không hiện sửa/loại slot; terminal booking không hiện cancel/complete. Các nút CONFIRMED không dựa đồng hồ client để cho phép hủy/complete. Server vẫn quyết định ownership, thời gian, trạng thái. 409 tải lại dữ liệu và giữ code/correlationId. Lỗi mạng/timeout/kết quả chưa rõ không replay POST/PATCH/DELETE, chặn write tới khi tải lại đối chiếu. Logout/đổi tài khoản đổi session epoch, hủy dữ liệu dashboard cũ và bỏ response cũ; token chỉ memory.

Eligibility chỉ đánh giá hiện tại, có thể đổi sau response; không có cache lâu dài, start marker, startedAt/startedBy hoặc IN_PROGRESS. Backend response no-store. Không ghi UI “đã bắt đầu buổi tập”; complete giữ R04 độc lập.

### Fixture lifecycle theo thời gian thật

Sau Seed, ServeBackend và Policy như trên, trước thao tác UI:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action LifecycleSeed -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action LifecycleSnapshot -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
~~~

LifecycleSeed đăng ký UUID trong manifest trước INSERT. Tạo6slot/5booking synthetic, cùng PTA và MemberA: session hiện tại start=now−30phút,end=now+60phút; session đã hết start=now−3giờ; tương lai +24giờ cho Member cancel/rebook,+28giờ cho PT cancel,+32giờ có lịch sử CANCELLED cho PATCH trả UUID mới,+36giờ chưa booking cho DELETE. Chỉ membership fixtureA được mở start_date về hôm qua để bao phủ session qua nửa đêm Việt Nam. Không đổi Clock/app, không chờ90phút; seed không phải booking tạo qua UI. Seed lặp khi còn fixture báo no-op; snapshot từ chối ghi đè evidence đã có.

Thứ tự demo:

1. MemberA hủy booking scenario memberCancel; MemberB login,chọn slot mở lại và đặt qua UI. Booking mới có UUID riêng, không thay booking cũ theo slotId.
2. PTA kiểm tra current eligible=true; booking tương lai eligible=false/SESSION_NOT_STARTED; dialog hiển thị thời gian Việt Nam và UTC. Làm trong vòng60phút sau seed để current chưa kết thúc; nếu hết cửa sổ thì cleanup/seed một chu kỳ mới.
3. PTA complete scenario ended, không cần GET eligibility cho booking đó; PT cancel scenario ptCancel với reason; PATCH scenario replacement sang giờ chưa chồng slot, sau đó sửa lần nữa dùng UUID mới; DELETE scenario delete.
4. Logout/login PTB chỉ thấy dữ liệu của B; reload/login MemberB vẫn thấy booking rebook. Không bấm hủy booking B khi chỉ kiểm tra persistence.
5. Chạy probe và DB audit:

~~~powershell
node frontend/verify-booking-lifecycle.mjs $manifest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action LifecycleAudit -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
~~~

Probe giả định các scenario đã được thao tác theo thứ tự này, reason PT là Demo PT unavailable, replacement còn AVAILABLE. Probe chỉ ghi requests kỳ vọng bị từ chối (sai quyền/repeated cancel/đặt slot DISABLED); không tự thực hiện các thao tác thành công thay UI. DB audit đối chiếu metadata, trạng thái và snapshot booking/slot/account/profile/membership current không đổi; ghi13checks. Không cộng checks vào Flutter tests.

Capture/Audit tự đăng ký UUID mới thuộc đúng PT/member fixture, gồm booking rebook và slot thay thế. Cleanup xác minh ownership lại và DELETE từng UUID manifest trong transaction; không truncate/xóa theo ngày. Sau logout và dừng đúng hai static servers/Backend của phiên, chạy Cleanup khi DB còn hoạt động, lặp Cleanup để kiểm no-op rồi stop đúng container nếu tự khởi động; giữ volume. Không cấp credential Admin cho Member/PT app.
