# Portable Core setup và demo tích hợp — Windows

[Repository overview](../README.md), [trạng thái](PROJECT_STATUS.md), [quyết định](DECISIONS.md). Đây là **guarded rehearsal trên DB test riêng**, không production install. Chuỗi V1–V6,V8–V13 frozen, không V7; `releaseReady=false` cho đến khi inventory/order/backfill DB được thống nhất. [R01 snapshot](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md) ghi các lỗi trước R02.

## Công cụ và cấu hình máy đích

Windows PowerShell5.1, Git (fetch refs Database), Docker Desktop **local Linux engine** `desktop-linux`; JDK21; Node; Flutter3.50.1/Dart3.14 (giữ pubspec/lock); Chrome cho Web. Python3.12 riêng để chạy Face protocol regression, theo [requirements lock](../face/service_v2/requirements-lock.txt). Không cần model/ảnh để chạy các protocol tests. Máy có phiên bản SDK tương thích khác phải xác minh, không hạ constraints hoặc upgrade hàng loạt dependency.

Cài công cụ từ nhà phát hành vào thư mục tools riêng, không commit SDK/cache. Maven Wrapper/Pub/Python/Playwright có thể tải dependency; nếu dùng cache phải ghi rõ, không gọi đó là cold install. Runtime Face và Flutter bootstrap tham khảo [F03A](backend-handover/24_FACE_SERVICE_QUICKSTART.md) và [provenance Flutter](backend-handover/evidence/BOOKING_WEB_INTEGRATION.md), các đường dẫn máy cũ chỉ là evidence, không điều kiện bắt buộc.

```powershell
# Tại repo root; dùng đường dẫn thực tế trên máy của bạn.
$jdk = Read-Host 'Thu muc JDK21'
$flutter = Read-Host 'Duong dan flutter.bat'
$python = Read-Host 'Python3.12 venv co requirements Face protocol'
$tools = Read-Host 'Thu muc cong cu rieng ngoai Git'
$private = Join-Path $env:LOCALAPPDATA ('Temp/fitcenter-core-'+[guid]::NewGuid().ToString('N'))
$runner = 'backend/scripts/core-readiness.ps1'
git fetch origin
# Chrome + Playwright helper (nếu chưa có); package không vào repository.
npm.cmd install --prefix "$tools/playwright" --no-audit --no-fund playwright@1.56.1
$playwright = Join-Path $tools 'playwright/node_modules/playwright/index.mjs'
```

Không đặt private scope dưới bất kỳ Git repository hoặc thư mục sync/upload. Không sao chép `.dpapi`, `account-resource.json`, `demo-fixture.properties` hoặc build từ máy khác. Sample tên biến ở [backend/.env.example](../backend/.env.example); file này không được tự load, password/JWT để trống. Runner sinh secrets ngẫu nhiên riêng và chỉ truyền vào process. DPAPI chỉ dùng trên máy/User hiện tại.

## Bootstrap mới và kiểm tra guard

Image17.12 Linux/amd64 được ghim tại [image lock](../backend/scripts/postgres-rehearsal-image.json), không dùng floating tag. Runner kiểm RepoDigest/platform và `postgres --version`; dùng cache nếu có, nếu thiếu chỉ pull đúng digest. Không inspect/in credential container khác. Resource mới có namespace ngẫu nhiên, label scope/task, named volume riêng. Ports **127.0.0.1:15437/15441** phải trống; đây là ports đã được Java/test guards chấp nhận. Collision phải dừng để người vận hành giải quyết, không tự stop container khác hoặc nới guard/đổi port để né kiểm tra.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Provision -JavaHome $jdk -PrivateDirectory $private
$id = (Get-Content "$private/account-resource.json" -Raw | ConvertFrom-Json).containerId
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Build -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Verify -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
```

Provision tạo hai container/volume mới, role không superuser/createdb/createrole/replication/bypassrls, credentials và authority cục bộ. Không cần baseline container hoặc ID cũ. Build package Backend, đối chiếu compiled SQL với exact frozen manifest **trước Flyway**, rồi chỉ migrate baseline DB mới V1–V6. Build lại chỉ validate history đầy đủ, không tự nâng/reset DB. Các pair integrated test/demo tạo nonce mới, kiểm datasource/role trước migrate. Không đổi default profile hoặc shared database.

Guard giữ fullID/context/image/label/namespace/named-volume/loopback-port và identity/history/checksum. Unknown SQL, manifest thiếu/thừa, đổi image/ID hoặc history lạ phải fail. Không lấy tất cả SQL trên đĩa làm manifest tự chấp nhận. Nếu provisioning dừng giữa chừng, giữ `provision-intent.json`/volume để đối chiếu, không Provision đè hoặc xóa resource dựa vào tên gần giống.

## Focused và regression

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-portable-guards.ps1 -OutputPath "$private/guard-results.json"
node --test backend/scripts/rehearsal-resource.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Test -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id -Python $python
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Test -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id -Python $python -FullSuite
```

Focused Face transport/enrollment là subset của selected full, không cộng. Full giữ selector Booking/default + integrated Account/M03/Renewal/F01/F02/F03A; loại standalone profile `PtActivationPostgresTest`, `ActivationSchemaRehearsalTest`, `InitialMembershipPostgresTest` đã có integrated replacements. Ghi rõ suites/skips thực tế, không gọi là mọi profile/E2E. JDK UTC chỉ scope process. Raw logs, fixture authority, test mail và Python service journals ngoài Git; không log secret/OTP/token.

Các inventories lịch sử I01/Renewal/F01 vẫn fail-closed khi candidate khác: checkout lần lượt d2774c9/4af8bb8/c3eb411 để tái lập evidence cũ, hoặc dùng entrypoint hiện hành. Không bỏ assertion để làm pass. Current exact inventory là [F02 candidate](../database/enrollment-integration-candidate.json), scripts cũ không phải current release plan.

## Kiểm Web runtime assets

Build thành công chưa đủ nếu cache Web SDK bị thiếu CanvasKit JavaScript. Static server hiện kiểm cả JS/Wasm và local-renderer config trước listen, không serve trang trắng hoặc tự fallback CDN. Nếu thiếu: dùng đúng Flutter SDK đã pin, chạy `flutter precache --web --force` từ nguồn SDK chính thức hoặc khôi phục artifact từ bundle cùng phiên bản đã kiểm SHA, rồi build lại. Không nâng SDK/dependency hoặc copy build của worktree cũ.

```powershell
node --test frontend/web-build-preflight.test.mjs
```

## Demo ba Web app, một Backend/DB/mail

Build cả ba app với cùng API base và giữ lock:

```powershell
foreach ($app in @('member','pt','ad')) {
  Push-Location "frontend/fitcenter_$app"
  try {
    & $flutter pub get --enforce-lockfile
    & $flutter analyze --no-fatal-infos
    & $flutter test --reporter expanded
    & $flutter build web --no-pub --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:18086/api/v1
  } finally { Pop-Location }
}
```

Mỗi scenario dùng một pair DB mới và Admin-only fixture riêng. Core: plan/accounts/M03/policy/OTP/slot/booking/cancel/rebook qua API/UI; Renewal: các plan/accounts/M03/OTP/PENDING/simulator/period read-back qua API/UI. Không seed Member ACTIVE để giả account activation. Dùng Clock thật, không giả hoàn thành buổi tương lai.

```powershell
$scenario = 'Core' # Lượt riêng tiếp theo dùng Renewal.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action PrepareDemo -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id -Scenario $scenario
$demo = Join-Path $private ('demo-'+$scenario.ToLowerInvariant())
# Terminal riêng: backend và sink phải dùng cùng demo scope.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action ServeBackend -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id -Scenario $scenario
node frontend/account-integration-mail-sink.mjs $demo
node frontend/serve-booking-web.mjs member
node frontend/serve-booking-web.mjs pt
node frontend/serve-booking-web.mjs ad
```

Các dòng server chạy ở **terminal riêng** hoặc background helper Hidden có PID/start-time registry. Ports18086/3000/3001/3002/11035/11036 phải trống. CORS chỉ đúng3origin localhost; DB/sink/backend loopback, không firewall/LAN/wildcard. Scoped demo authority được tạo mới từ resource của chính phiên bootstrap, chỉ ghi run mới; không import authority/creds máy cũ. Không chạy Test/NewRun trong khi demo server đang dùng run.

Cho harness, nạp PGPASSWORD vào **process** từ DPAPI của demo bằng `ConvertTo-SecureString`/`Net.NetworkCredential`, không in giá trị. Sau đó:

```powershell
node frontend/verify-core-integration.mjs $demo $playwright --current
# Scenario Renewal trên pair khác: stop đúng Backend/mail Core trước khi đổi scope.
node frontend/verify-renewal-integration.mjs $demo $playwright --current
```

Không chạy hai harness trên cùng pair hoặc replay write sau lỗi. Nếu timeout, đối chiếu intent/UUID ledger trước cleanup; không dò plan theo tên vì name không unique. Member/PT/Admin auth token memory; reload/login đọc lại server. Face test config có kiosk tổng hợp riêng theo guard nhưng không có capture/profile binding: không admission thật. Default Face vẫn off; F03B dataset/calibration/evaluation đang hoãn. Simulator ghi “Thanh toán mô phỏng”, không thu tiền thật. Các module chưa có API hiện Chưa khả dụng; chỉ Web được kiểm chứng.

## Cleanup

Dừng đúng browser/backend/mail/static-server PID/start-time/command line của task trước cleanup, không tắt Docker engine chung khi còn workload khác. Cleanup hỗ trợ cả hai scenario scopes và các test-run registries:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Cleanup -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
# Lặp lại để kiểm idempotent/outside-row preservation.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Cleanup -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Stop -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
```

Chỉ UUID có ledger, không truncate/broad delete/drop/clean/repair. Giữ named volumes/schema/history và dữ liệu ngoài fixture. Không xóa private authority khi chưa kiểm cleanup xong; credentials/consent/dataset không đưa vào Git.

## Fresh install và upgrade

Fresh rehearsal dùng **resource/pair mới** theo trên, không tái sử dụng shared DB. Đây không phải đường production fresh-install; canonical release mới chưa được chốt. Default chỉ V1–V6 vẫn dùng account test có sẵn, không tự bật Account/Membership write mới.

Với DB hiện hữu, người quản lý DB chạy [inventory chỉ đọc](../database/tools/read-only-inventory.sql) qua tài khoản read-only; hướng dẫn ở [DB inventory](DB_INVENTORY.md). Task này không kết nối DB chung. Phải biết version/script/checksum/status, schema/period/receipt/snapshot/activation state và backup trước kế hoạch upgrade. Không giả định V7 chưa áp trên máy đồng đội. Không áp V7 DROP chưa backfill, không sửa V1–V13/renumber/history/out-of-order/repair để né gap7. Nếu V7 đã áp, dữ liệu bị drop cần nguồn backup/reconciliation thật; không dựng lại từ giá plan hôm nay. **releaseReady=false** cho đến khi inventory/backfill/order được đồng bộ và kiểm chứng riêng.

## Kết quả và giới hạn đã kiểm chứng

[R02 evidence](backend-handover/evidence/R02_PORTABLE_SETUP.md) ghi source commit, suites thực chạy, UI/HTTP/DB, cache dùng, lỗi đã sửa và cleanup. Không dùng counts lịch sử làm lượt vừa chạy; máy mới phải chạy guard và selected tests theo scope của mình.
