# FitCenter — trạng thái tiếp tục

Cập nhật25/11/2026, branch **integration/core-main-readiness**, R01 checkpoint **a2051b9b758698aae3946e62261c4f2cdc2566bf**, parent F03Bf45d55a. Task **R-02 portable setup/tài liệu**, đang kiểm chứng, chưa merge main. Git là thực tế.

## Đã sửa, đang chờ gate checkout sạch

Entrypoint [core-readiness.ps1](../backend/scripts/core-readiness.ps1) tái sử dụng runner/harness, bootstrap PostgreSQL17.12 pinned digest thành container/volume/keys/authority mới. Không cần baseline container/ID/DPAPI máy cũ; full dùng baseline authority mới. Guard fullID/context/image/volume/namespace/loopback/database/role/history và exact SQL giữ nguyên; compiled resources kiểm trước Flyway. Historical inventory vẫn fail-closed và hướng chuyển sang runner hiện hành/pin commit.

[README root](../README.md), [setup thống nhất](INTEGRATION_SETUP.md), [Backend README](../backend/README.md), env template không secret;10links đã chuyển sang nguồn tracked, không stage4research. [DB inventory SQL chỉ đọc](../database/tools/read-only-inventory.sql) dành cho owner dùng sau này, task không kết nối DB chung.

Focused thực chạy trong dev scope: **63Backend tests passed,0failed/errors/skipped**; **21PowerShell guard/parser checks**, **16Node guard tests** đạt; unknown SQL bị inventory từ chối. Package/baseline6 và Admin-only demo12migrations chạy trên2container mới. Cleanup exact ledger lặp lại đạt, dừng đúng2container dev, giữ volumes. **Chưa có full regression/E2E của candidate cuối**; sẽ clone sạch và provision namespace/credentials mới để kiểm chứng, không copy build hoặc private authority của worktree.

## Giới hạn giữ nguyên

V1–V6,V8–V13 nguyên bytes; V7 không import/apply. Chuỗi rehearsal không canonical release, shared inventory/order/backfill chưa thống nhất: **releaseReady=false**. Default profile/gates giữ nguyên. Simulator dev/test, không gateway/refund; Face thật chưa nghiệm thu. F03B **tooling ready; dataset/calibration/evaluation người thật chưa chạy**, không accuracy/threshold change, liveness NOT_PERFORMED/admission thật off. Không mở camera hoặc thu mẫu.

Worktree có source/scripts/docs R02 chưa commit ở thời điểm này;4researchuntracked22/11 và26Face/caches/model ngoài task được giữ. Không credentials/manifests/rawlogs/build/SDK/dataset trong phạm vi stage. [R01 report](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md), [quyết định](DECISIONS.md), [AGENTS](../AGENTS.md).
