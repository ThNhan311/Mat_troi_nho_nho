# Quickstart — Booking Member/PT trên Flutter Web

Lát cắt đầu login → PT tạo slot → Member đặt và lịch hai bên đã đóng bằng commit9fe34b9. Lifecycle đã đóng bằng cb749ae. Nhánh hiện tại feature/frontend-original-ui-integration đưa logic đã kiểm chứng vào Login/Home/navigation và screen gốc; Backend base089b5e2, Frontend nguồn0307242. [Kết quả](evidence/BOOKING_WEB_INTEGRATION.md), [khảo sát](evidence/FRONTEND_INTEGRATION_SURVEY.md).

## Source và SDK

Làm từ worktree tích hợp. Hai project: [Member](../../frontend/fitcenter_member), [PT](../../frontend/fitcenter_pt). Production Backend/V1–V6 giữ nguyên; không alignment/V7. Membership/Payment/Workout/Face không được nối API; navigation gốc hiện Chưa khả dụng cho module chưa có contract. Dashboard trước được giữ cho regression riêng, không là entry chính.

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

## Giao diện gốc và UI runner (task hiện tại)

Entry thực tế là Login → Home/navigation gốc. Member: PT list/detail → Lịch tập/calendar → Cá nhân/Lịch sử đặt lịch. PT: Lịch làm → Buổi tập → Chi tiết. Không cần dùng dashboard thay thế. [Báo cáo và ảnh trước/sau](evidence/ORIGINAL_UI_INTEGRATION.md).

Có thể kiểm chứng tự động bằng Chrome headless thật, vẫn qua các widget Web và Backend/PostgreSQL demo riêng. Playwright1.65.1 chỉ nằm trong thư mục công cụ local (npm registry chính thức + integrity package lock), không thêm dependency hai app. Cần Chrome đã cài; tùy chọn CHROME_EXECUTABLE chỉ trỏ executable được người vận hành xác minh.

~~~powershell
$uiTools = Join-Path $env:LOCALAPPDATA 'Temp\fitcenter-ui-tools'
npm.cmd install --prefix $uiTools playwright@1.65.1 --ignore-scripts --no-audit --no-fund
$playwright = Join-Path $uiTools 'node_modules\playwright\index.mjs'
# Dùng manifest trong Temp riêng theo phần trên, DB/backend và hai web server đang chạy.
# Chuẩn bị một lượt mới: Seed, Policy (Admin PUT), LifecycleSeed, LifecycleSnapshot.
foreach ($action in @('LifecycleSeed','LifecycleSnapshot')) {
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action $action -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
  if ($LASTEXITCODE) { throw 'Dừng và kiểm tra fixture' }
}
foreach ($phase in @('pt-create','member-book','member-cancel-rebook','pt-lifecycle-final','pt-availability','owners','ui-error-feedback')) {
  node frontend/verify-original-ui.mjs $manifest $playwright $phase
  if ($LASTEXITCODE) { throw 'Dừng; Capture/Audit kết quả trước khi làm gì tiếp' }
}
~~~

Đây là các pha của **một lượt fixture sạch**. Runner ghi original-ui-results.json cạnh manifest, lưu 74 source hashes của app/tests/helper/config, và lưu write intent trước khi thao tác. Không sửa source giữa các pha. Không xóa/đặt lại intent để chạy lại write khi timeout. Pha member-read-only chỉ login/GET/reload booking đã ghi nhận; không tạo booking mới. Khi một pha đã chạy dở: đọc trace + Capture/Audit/DB, rồi cleanup đúng manifest. Lượt mới cần private manifest/results sạch; lưu evidence cũ trước. Không ghi đè credentials hoặc manifest khác.

PT create và Member book tạo slot/booking thật qua UI. Member cancel/rebook và PT cancel/complete cũng qua UI. LifecycleSeed tạo trước các booking tổng hợp: Member-cancel tương lai, PT-cancel tương lai, AVAILABLE có lịch sử CANCELLED để PATCH thay ID, AVAILABLE để DELETE, CONFIRMED đang diễn ra và CONFIRMED đã kết thúc. Đó là dữ liệu seed, không tuyên bố chúng được tạo qua UI. Current/ended được tính bằng thời gian thật; không sửa Clock production, không chờ90phút. Chạy eligibility trong cửa sổ current còn hiệu lực; hết cửa sổ thì cleanup rồi seed lượt mới.

UI error phase kiểm 409 deadline Backend thật; network abort và repeated GET401 là fault injection ở browser để kiểm client không fake success/replay và refresh giới hạn. Hai HTTP probes kiểm role/ownership thật. Không cộng assertions UI, HTTP, DB và Flutter thành một số tests.

Sau UI:

~~~powershell
# Đối chiếu đúng booking UUID lấy từ UI results, không dùng ID ví dụ.
node frontend/verify-booking-demo.mjs verify $manifest '<UI-booking-UUID>'
node frontend/verify-booking-lifecycle.mjs $manifest
foreach ($action in @('Capture','Audit','LifecycleAudit','Cleanup')) {
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action $action -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
  if ($LASTEXITCODE) { throw 'Dừng kiểm tra đích/manifest' }
}
~~~

Nếu shell đặt TMP/TEMP vào một sandbox khác, hai probe cũ yêu cầu manifest nằm dưới os.tmpdir(); chạy chúng trong process có TMP/TEMP trỏ thư mục Temp chứa manifest đã xác minh. Không di chuyển credential vào repo để vượt guard. verify-booking-demo dùng nhánh **verify**, không dùng claim khi đối chiếu. Lifecycle probe đọc metadata trước, chỉ gửi các negative request dự kiến409/403/404, không tạo rebook/replacement thay UI.

Cuối cùng dừng đúng PID/command line của Node serve-booking-web, Java/guarded runner do lượt này khởi động; xác minh port3000/3001/18081 đã đóng. Dừng đúng container đã verify ID/label/volume, giữ volume. Không kill theo tên process rộng hoặc stop container khác. Cleanup đã kiểm tám bảng về baseline0 và history1–6 thành công ở lượt nghiệm thu; đây không phải lệnh truncate.
## Admin Booking Policy Web

Task giao diện gốc Member/PT đã đóng local commit425a0a8. Admin đang ở feature/frontend-admin-booking-policy, giữ Home/BookingPolicyPage/theme từ0307242; [báo cáo và ảnh trước/sau](evidence/ADMIN_BOOKING_POLICY.md). Các phần lịch sử hai app phía trên vẫn là evidence của thời điểm đó; phần này bổ sung app thứ ba.

Từ [Admin project](../../frontend/fitcenter_ad), cùng SDK/PUB_CACHE riêng:

~~~powershell
& $flutter pub get --enforce-lockfile
& $flutter analyze --no-fatal-infos
& $flutter test --reporter expanded
& $flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1
# Từ repository root, server riêng:
node frontend/serve-booking-web.mjs ad
~~~

Admin ở http://localhost:3002. Kiểm port trống trước khi chạy. ServeBackend dùng guard như trên, **thêm -IncludeAdminWeb** để CORS process có đúng http://localhost:3000, http://localhost:3001, http://localhost:3002. Không có switch thì giữ hai origin cũ. Không sửa cấu hình Backend chung hoặc wildcard.

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action ServeBackend -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest -BackendPort 18081 -IncludeAdminWeb
~~~

Để demo cấu hình đầu tiên: dùng DB demo riêng đã guard/cleanup sạch, Seed actors như trên nhưng **không chạy action Policy trước UI**. Login Admin bằng credential trong manifest ngoài Git → Home gốc → Chính sách đặt lịch. GET404 phải hiện chưa cấu hình và form trống. Nhập14/2/4/5, lưu200; reload/login lại phải đọc đúng UUID/giá trị/effectiveFrom server. Đây là cấu hình fixture, không phải fallback nghiệp vụ. Không cấp Admin token cho Member/PT.

[UI runner](../../frontend/verify-admin-policy-ui.mjs) yêu cầu Playwright ngoài repo như phần trên. Chạy đúng thứ tự trong một lượt fixture sạch. Results `admin-policy-ui-results.json` nằm cạnh manifest, có source hashes và write intents. Không xóa intent để thử lại write; khi lỗi phải Capture/đối chiếu DB, giữ kết quả riêng và cleanup trước một lượt mới. Kết quả cũ cần archive local với tên riêng; không ghi đè manifest/credential khác.

~~~powershell
node frontend/verify-admin-policy-ui.mjs $manifest $playwright initial
# initial đã đăng ký policy UUID vào manifest sau UI PUT200.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/booking-demo.ps1 -Action LifecycleSeed -JavaHome $JavaHome -ExpectedContainerId $verifiedId -ManifestPath $manifest
# Probe DB cần PGPASSWORD chỉ trong process, từ secret store/prompt riêng; không ghi ra terminal.
node frontend/verify-admin-policy-demo.mjs $manifest baseline
node frontend/verify-admin-policy-ui.mjs $manifest $playwright restrict
node frontend/verify-admin-policy-demo.mjs $manifest restrict
node frontend/verify-admin-policy-ui.mjs $manifest $playwright allow
node frontend/verify-admin-policy-demo.mjs $manifest allow
node frontend/verify-admin-policy-ui.mjs $manifest $playwright feedback
~~~

LifecycleSeed tạo booking tổng hợp trước khi đổi policy, không phải UI tạo booking ở task này. Restrict: Admin đổi deadline48/maxfuture1, MemberA hủy booking future24giờ qua lịch sử gốc →409; DB mọi booking/slot không đổi. Allow: Admin đổi deadline0, cùng booking hủy200 → CANCELLED/AVAILABLE; booking khác giữ nguyên. Không đổi Clock production/chờ90phút. Feedback abort PUT bằng browser route để kiểm no-replay và GET đối chiếu; không sửa server.

Nếu UI PUT đầu tiên được thao tác thủ công thay runner: ghi **đúng UUID response** vào key policy của manifest local sau khi kiểm policy đó thuộc Admin fixture; không thay UUID đang trỏ policy khác. Cleanup chỉ xóa policy UUID có updated_by đúng actor fixture. Không cleanup bằng xóa toàn bảng nếu thất bại/chưa rõ.

Sau kiểm tra, logout, dừng đúng PID ba static server/Java/guarded wrapper do lượt này tạo, Capture rồi Cleanup như trên; chạy Cleanup lần hai để kiểm idempotence. Kiểm rows fixture/history, dừng đúng DB nếu tự khởi động, giữ volume. Không để port3000/3001/3002/18081 hoặc tài khoản demo còn chạy mà báo đã cleanup.

Không làm Admin UI khác hoặc API/migration mới. Admin API chỉ cho ADMIN; Member/PT không được gọi policy Admin để hiển thị deadline. D01 vẫn là snapshot eligibility, completion vẫn theo R04.