# FitCenter — trạng thái tiếp tục

Cập nhật25/11/2026, branch **integration/core-main-readiness**. R01 đã commit riêng **a2051b9**; executable candidate cuối **44d5798**, sau portable **ce54e00** và demo config **05ba48c**. Commit đóng R02 chỉ thêm tài liệu/evidence; dùng Git để xác minh HEAD/remote thực tế. **R02 đã kiểm chứng portable rehearsal, chưa merge main; releaseReady=false.**

## Đã kiểm chứng trong R02

[Entrypoint portable](../backend/scripts/core-readiness.ps1) bootstrap PostgreSQL17.12 pinned digest thành container/volume/credentials/authority mới, không baseline ID/DPAPI máy cũ. Guards fullID/context/image/volume/namespace/loopback/role/database/history/exact SQL và compiled hashes giữ nguyên. Default gates không thay. [README](../README.md), [setup3app thống nhất](INTEGRATION_SETUP.md), [inventory DB chỉ đọc](DB_INVENTORY.md), historical quickstarts pin commit;10research links sửa sang nguồn tracked.

Checkout sạch dùng cache, không copy credential/manifest/build. Full Backend tại ce54e00: **1106passed,0failed/errors/skipped,43selected suites**; Backend src/POM/schema/Dart/app trees không đổi tới final candidate. Focused63 là tập con, không cộng. Guards21PowerShell/16Node, Web asset preflight5 đạt. Flutter Member80/PT55/Admin133 tests đạt; analyze/build3app exit0. Đã sửa thiếu CanvasKitJS trong cache cùngSDK và rebuild, không upgrade SDK/dependencies.

UI thật tại44d5798: Core **26UI/29HTTP/9DB**, Renewal **29UI/18HTTP/10DB**,0failed/skipped. Admin-only seed; accounts, plan, Membership, OTP activation, slot/booking và renewal dùng API/UI thật. Reload/login, ownership, cancel/rebook, paid periods, replay và DB readback đạt. Không gọi selected integration flows là toàn bộ FitCenter E2E. [Evidence/giới hạn](backend-handover/evidence/R02_PORTABLE_SETUP.md), [kết quả/suites](backend-handover/evidence/R02_RESULTS.json), [27source hashes](backend-handover/evidence/R02_SOURCE_HASHES.json).

Cleanup exact UUID lặp2lần đạt, giữ3rows ngoài fixture; dừng đúng tài nguyên/process task, giữ volumes.4research untracked22/11 và26Face/model/cache ngoài task được giữ. Không credentials/manifests/rawlogs/build/SDK trong staged scope. Không DB chung/production.

## Blocker và bước tiếp theo

Chuỗi V1–V6,V8–V13 chỉ rehearsal, nguyên bytes; V7 không import/apply. Thiếu shared DB inventory/order/backfill/backup nên **releaseReady=false**. Owner chạy [inventory chỉ đọc](DB_INVENTORY.md), đối chiếu V7/V8+ thực tế rồi thống nhất canonical fresh/upgrade chain; không out-of-order/history edits/clean/repair hoặc sửa migration đã công bố. Có thể mở PR portable/docs để review, ghi rõ default-off/release blocker; chưa merge.

Main5c8693b/Database558fb03/frontend0307242 không đổi khi fetch cuối; main0workflow runs/0statuses từ connector, không phải CI pass. R02 dùng cache image/Maven/Pub/SDK/Playwright/Python, chưa cold-install máy mới/native/mobile/deploy.

F03B **tooling ready; dataset/calibration/evaluation người thật chưa chạy**, camera không mở lại, không accuracy/threshold change. Face thật chưa nghiệm thu, liveness NOT_PERFORMED/admission thật off. Simulator dev/test, không gateway/refund. [Quyết định](DECISIONS.md), [AGENTS](../AGENTS.md), [R01](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md).
