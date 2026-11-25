# FitCenter — trạng thái tiếp tục

Cập nhật25/11/2026, branch **feature/db01-migration-compatibility**, HEAD tại lúc viết/source candidate **fd603d7ad1939caf868f663c7e560bc63767bfcf**, base R02 **ee95e0c**. Commit đóng tiếp theo chỉ docs/evidence; Git là HEAD/remote thực tế. **DB01 private rehearsal đạt, releaseReady=false; chưa merge main/DB chung.**

## DB01 đã làm và kiểm chứng

[Hai đường upgrade/inventory/setup](DB01_UPGRADE.md): compatibility callback backup/restore payment dates **trước V9/V11**, giữ nguyên V1–V13; candidateV14 ngoài default locations hợp nhất `membership_paid_periods` làm nguồn kỳ duy nhất, V7 archive + read-only view. Không tạo COUNTER/receipt/quote giả từ legacy ACTIVATION; missing provenance/refund/conflict phải dừng. Slot14/callback release chưa duyệt khi chưa có inventory target.

Thực chạy **196migration/JDBC-service checks,13scenarios,0failed/skipped** trên PostgreSQL17.12 riêng/JDK21; selected JUnit **79passed,0failed/errors/skipped,6suites**. Inventory READ ONLY trên3private DBs, target mismatch guard và fingerprints đạt; unknown SQL/fullID bị từ chối. Clean clone candidate hashes/LF/parser/inventory đạt. Không cộng checks vào JUnit hoặc gọi HTTP/UI E2E; full1106 và Flutter/R02 là lịch sử, không vừa chạy lại.

Kiểm actual M03/renewal snapshots/receipt/retry/concurrency/rollback, activation-state preservation, Booking/D01 paid coverage/ngày nhuận/gap. Cleanup exact sealed PK2lần đạt, outside sentinel giữ nguyên rồi xóa đúng UUID của task; stopped đúng container, giữ volume.4research untracked và26Face/model/cache nguyên hashes; production Java/POM/Dart/default gates/published SQL không đổi. [Evidence](backend-handover/evidence/DB01_MIGRATION_COMPATIBILITY.md), [results/source hashes/version matrix](backend-handover/evidence/DB01_RESULTS.json).

## Blocker và bước tiếp theo

Chưa xác định/kết nối DB chung; inventory/backup/applied V7/V8+/version14 slot UNKNOWN. Owner chạy [DB01 inventory](DB01_UPGRADE.md#đích-và-inventory-bắt-buộc), đối chiếu source/consumer, review callback maintenance/order/backfill trước rollout. Không repair/history edits/out-of-order/clean, không renumber hoặc tự mở default gates.

M04 legacy planName fallback cần sửa nếu current period plan khác aggregate FK và thiếu snapshot; consumer V7 chỉ nhận2source cần điều chỉnh LEGACY handling. Refund/sources thiếu cần đối soát riêng, không infer từ plan hiện tại. DB01 không sửa API/Frontend hoặc quảng bá canonical release sẵn sàng.

R02 portable setup vẫn ở [quickstart](INTEGRATION_SETUP.md), [evidence R02](backend-handover/evidence/R02_PORTABLE_SETUP.md). Main5c8693b/Database558fb03/frontend0307242 chưa đổi qua fetch. F03B tooling ready, dataset/calibration/evaluation đang hoãn; liveness NOT_PERFORMED/admission thật off, không camera hoặc dữ liệu sinh trắc mới. [Quyết định](DECISIONS.md), [AGENTS](../AGENTS.md).
