# R-02 — Portable setup và tài liệu tích hợp, 25/11/2026

**Portable guarded rehearsal đã chạy từ checkout sạch; canonical release chưa sẵn sàng.** [Kết quả chọn lọc](R02_RESULTS.json), [27 executable source/helper/test hashes](R02_SOURCE_HASHES.json), [setup/demo thống nhất](../../INTEGRATION_SETUP.md), [R01 baseline](R01_MAIN_INTEGRATION_READINESS.md).

## Source và phạm vi

Nhánh `integration/core-main-readiness`, từ F03B `f45d55a77d7338cdfbe5ad9aeb4df2f18cea0c3d`. R01 đóng riêng tại `a2051b9b758698aae3946e62261c4f2cdc2566bf`; không gộp4research ngoài Git. Portable candidate `ce54e002a5047c423f33b9da4327de2c53283cf2`, sửa config demo `05ba48cf1880df84647eedea6a36498e939108d0`, Web asset preflight `44d579863d6c703fc062d83c8a6b4d6655cd1b55`. Commit sau candidate chỉ đóng tài liệu/evidence; Git là HEAD thực tế.

Clone mới `--no-hardlinks --no-checkout` từ commit local, đặt origin GitHub và fetch refs; checkout detached đúng candidate. Không copy source untracked, credentials/DPAPI, manifest hoặc build của worktree đang làm. Hai scope dev và clean sinh độc lập container/volume/namespace/keys mới, so sánh password trong memory xác nhận khác nhau. Các container FitCenter cũ vẫn dừng. **Dùng cache** image, Maven, Pub, SDK/verified archive, Playwright/Chrome và Python runtime; không gọi đây là cold install hoặc xác minh toàn bộ máy Windows mới.

Không đổi executable Java trong `backend/src`, POM, Dart/app trees, API/nghiệp vụ hoặc SQL migration. Các tree này tại full-tested `ce54e00` và E2E `44d5798` giống nhau; source hashes ghi riêng raw bytes của clean checkout/working tree và Git blob để không nhầm CRLF/LF với thay code.21native generated paths trong clone chỉ khác EOL sau pub, không mang về source/stage.

## Blocker R01 đã xử lý

- [Entrypoint](../../../backend/scripts/core-readiness.ps1) dùng [helper](../../../backend/scripts/portable-resources.ps1) tạo baseline và Core DB mới từ [PostgreSQL17.12 digest lock](../../../backend/scripts/postgres-rehearsal-image.json). Không baseline container/ID hoặc DPAPI máy cũ. Private keys/authority CREATE_NEW, không ghi đè resource/credential đã tồn tại.
- Full container ID/context/image/namespace/volume/loopback port, nonprivileged role/database và history guards giữ nguyên. Exact frozen12SQL kiểm cả source và compiled resources **trước Flyway**. Probe unknown SQL bị từ chối; lịch sử inventories vẫn fail-closed, có hướng pin commit/chuyển runner.
- [README root](../../../README.md), [Backend README](../../../backend/README.md), env mẫu không secret, một quickstart hiện hành cho3app. Không còn hướng người mới vào alignment.10links phụ thuộc4research được chuyển sang nguồn tracked; một link Topic11 ngoài repository được ghi rõ provenance/tệp bàn giao ngoài Git, không giả source có trong clone.
- [Inventory SQL](../../../database/tools/read-only-inventory.sql) chỉ đọc, có [hướng dẫn owner DB](../../DB_INVENTORY.md). Fresh rehearsal khác upgrade DB hiện hữu.
- [Static server](../../../frontend/serve-booking-web.mjs) kiểm tài nguyên renderer local trước listen, không âm thầm dùng CDN hoặc mở trang trắng khi SDK thiếu file.

## Kiểm thử mới thực chạy

| Nhóm | Kết quả | Source/phạm vi |
|---|---|---|
| Backend selected full | **1106 passed,0fail/errors/skipped**,43suites | Clean `ce54e00`, JDK21/PostgreSQL riêng; production runtime/schema/app trees không đổi sau đó. |
| Backend focused |63passed,0fail/errors/skipped|Bước dev trước full; **không cộng vào1106**.|
| PowerShell guards/parser |21passed|Identity/image/volume/loopback/private-path negatives và parser6runners. Không gọi đây là DB tests.|
| Node resource guards |16passed|Pure contract/guard tests, chạy cả clean checkout.|
| Web runtime preflight |5passed|Missing/empty runtime assets, CDN mode và missing bundle; clean checkout cũng đạt.|
| Flutter Member |80passed,0failed/skipped|Analyze exit0, client/widget tests, web build exit0.|
| Flutter PT |55passed,0failed/skipped|Như trên.|
| Flutter Admin |133passed,0failed/skipped|Như trên.|
| Core UI / HTTP / DB |**26 /29 /9**,0failed/skipped|Clean `44d5798`, Chrome thật headless, viewport1024×768, browser America/Los_Angeles.|
| Renewal UI / HTTP / DB |**29 /18 /10**,0failed/skipped|Cùng backend/config/migration candidate trên pair mới, Admin-only seed.|
| Inventory chỉ đọc |2đích đạt|BaselineV1–V6 và CoreV13; READ ONLY, catalog/aggregates; row fingerprints trước/sau giữ nguyên.|

Selected full dùng `*Test` trừ `PtActivationPostgresTest`, `ActivationSchemaRehearsalTest`, `InitialMembershipPostgresTest`: đó là3suite location rehearsal lịch sử riêng; integrated Account/M03/renewal/F01/F02/F03A scopes thay thế có trong43suite, danh sách/counts đầy đủ trong JSON. Không gọi3suite không chọn là skipped=0 đã chạy. Python accuracy/camera/PAD suites không chọn trong task này. Flutter dùng `analyze --no-fatal-infos`, giữ informational lints; không hạ constraints/đổi dependencies.

Commands tái lập: [Provision→Build→Verify→Test focused/full→PrepareDemo→ServeBackend/mail/Web→harness→Cleanup→Stop](../../INTEGRATION_SETUP.md). Guard units: `test-portable-guards.ps1`, `node --test backend/scripts/rehearsal-resource.test.mjs frontend/web-build-preflight.test.mjs`. Full chạy qua `core-readiness.ps1 -Action Test -FullSuite`, không bare `mvn test` thiếu opt-in env. UI dùng `verify-core-integration.mjs ... --current`, rồi pair riêng `verify-renewal-integration.mjs ... --current`; không replay writes trên cùng registry.

## UI/DB và các lỗi đã sửa

Core: chỉ seed Admin; plan/account/policy/M03 được tạo qua UI/API, MEMBER/PT email→SMTP sink→OTP→password→ACTIVE rồi login. Membership không bị account activation sửa. PT tạo slot qua UI, Member đặt CONFIRMED, hai bên đọc cùng UUID/time, Member hủy mở lại slot rồi thao tác mới đặt lại. Repeated cancel cũ409 không đổi slot/booking mới; ownership/role/anonymous checks và reload/login readback đạt. [Member history](r02-portable/core-member-history.png), [PT sessions](r02-portable/core-pt-sessions.png).

Renewal: chỉ Admin seed, initial Membership thật, Member tạo PENDING qua UI, Admin simulator SUCCESS, Member reload/login thấy CURRENT/NEXT theo server, plan giá0 được hỗ trợ. FAILED/CANCELLED không đổi hạn; replay không thêm kỳ/audit; late failure không downgrade SUCCESS, ownership/role giữ nguyên. DB chứng minh receipt/payment M03 được giữ và Booking không đổi. [Admin simulator](r02-portable/renewal-admin-success.png), [Member paid periods](r02-portable/renewal-member-periods.png). Tất cả UUID/labels trong ảnh là dữ liệu tổng hợp; ảnh đã review không có credential/OTP/token.

Các attempt lỗi **không tính là E2E đạt**: config test ban đầu thiếu kiosk bắt buộc của guard; helper đã thêm kiosk synthetic riêng, không capture/profile binding/admission. Private readiness wrapper xử lý thiếu inner WebException401 đã sửa trong orchestration. Sau đó Flutter build exit0 nhưng cache SDK thiếu CanvasKitJS khiến browser404/trang trắng; phục hồi20JS/MJS thiếu từ chính official Flutter3.50.1 archive SHA256 `33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb`, xác minh file có sẵn khớp archive, không overwrite. Rebuild cả3app và final UI đạt như bảng. Thêm5preflight tests để lỗi thiếu asset dừng sớm. Không sửa app để bypass guard hoặc fallback mock.

## Cleanup, audit và giới hạn

Cleanup đúng UUID registry chạy **hai lần**: Core pair2DB/6checks; Renewal pair2DB/6checks; root20registered DB/60checks,0failed.3rows ngoài fixture giữ nguyên fingerprints. Các attempt lỗi được cleanup trước rồi archive authority riêng, không reset/reseed. Dừng đúng task process tree bằng PID/start-time/command, dừng đúng2container clean và2container dev; giữ volumes/schema/history. Ports18086/3000/3001/3002/11035/11036/15437/15441 đã giải phóng. Docker engine giữ chạy vì workload khác; không đổi workload đó.

12published SQL V1–V6,V8–V13 giữ raw hashes; V7 remote không import/apply.4research untracked và26Face/model/cache ngoài task giữ nguyên hashes. Latest tracked secret/artifact scan và clean-clone relative Markdown links được kiểm lại lúc đóng; không raw logs/private manifests/credentials/SDK/build trong commit. Không forensic toàn Git history/OCR tự động mọi ảnh cũ.

Fetch lại: main `5c8693b`, Database `558fb03`, frontend `0307242` không đổi. GitHub connector thấy main có0workflow runs/0commit statuses; không phải CI pass. Repository-wide REST không truy cập được trong lần recheck; counts workflow/deployment/webhook0 ở R01 là snapshot cũ, không đổi thành bằng chứng mới. Chưa thêm CI/CD hoặc deploy.

**Còn trước canonical release:** inventory thật từng DB đích, trạng thái V7/V8+ đã áp, backup/backfill periods và thống nhất version/order/forward-correction với Database owner. Không giả V7 chưa áp, không DROP chưa backfill, renumber/out-of-order/repair/clean/history edits. `releaseReady=false`; task không kết nối DB chung. Có thể mở PR review nhánh portable/docs với gates mặc định off và ghi rõ blocker release; chưa merge main.

Face thật vẫn default-off/chưa nghiệm thu, F03B tooling ready, dataset/calibration/evaluation đang hoãn; không accuracy/threshold change, liveness NOT_PERFORMED/admission thật off. Simulator chỉ dev/test, không gateway/refund. Native/mobile, cold install, exhaustive lifecycle UI traversal và production rollout chưa kiểm chứng mới ở R02.
