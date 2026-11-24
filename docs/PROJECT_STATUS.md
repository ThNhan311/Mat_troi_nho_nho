# FitCenter — trạng thái tiếp tục

Cập nhật24/11/2026, worktree Mat_troi_nho_nho-booking-integration; branch **feature/face-service-integration**, HEAD/base trước commit đóng **de82618c21d2aaeb2c3b1d39df4382b3928d93e7**. Git là thực tế; commit F03A xem history/final handover, file không chứa SHA của chính nó.

## F03A — protocol/service và inference smoke đạt, Face thật chưa hoàn thành

Private Face Service lifecycle prepare/stage/status/finalize/abort, immutable Member/profile/predecessor/generation, encrypted durable store/reservation/tombstones; Backend HTTP transport post-commit finalize/recovery. Capture proof ký/request-bound/expiry/provenance, Core recheck current mapping/generation nhưng không admission nếu chưa đủ evidence. Source algorithms/state dependencies nhập nguyên pinfcabeba; không thay prototype/camera gốc.

Thực chạy trên source cuối: **1106Backend selected full/43suites,0failed/errors/skipped**; focused63 là subset. **Python80selected=58repo+22pinned state/auth**,0failed/errors/skipped; protocol/formula tests synthetic, không biometric accuracy. Actual SCRFD/ArcFace weights buffalo_s đã nạp trên CPU: uniform-image detector, tensor512 forward và authenticated model HTTP NO_FACE; không dataset/calibration/PAD/camera. Không Dart/UI đổi nên không rerun Flutter hoặc dùng F02 UI cũ làm bằng chứng mới. [Evidence/limits](backend-handover/evidence/F03A_FACE_SERVICE.md), [suites/model JSON](backend-handover/evidence/F03A_RESULTS.json), [39hashes/provenance](backend-handover/evidence/F03A_SOURCE_HASHES.json), [contract/recovery](backend-handover/decisions/2026-11-24_F03A_FACE_SERVICE.md), [quickstart](backend-handover/24_FACE_SERVICE_QUICKSTART.md).

## Gates và phần chưa triển khai

Backend remote chỉ protocol test trên V13 SIMULATED_TEST; actual model provenance bị503, không ghi nhầm inference thật là simulated. NOT_PERFORMED không PASSED; actual enrollment/recognition admission, PAD, camera/kiosk GUI, approved dataset/threshold và production retention/license/legacy mapping **chưa đạt**. Không gọi F03 hoàn tất chỉ vì protocol passed. Không thay Membership/payment/Booking hoặc User/activation.

Không migration mới: candidate1–6,8–13/default-off giữ nguyên; V7 Duy558fb03 quarantine vì chưa backfill và shared DB history unknown. Cần đồng bộ/order/backfill/inventory trước merge/release, không renumber/out-of-order/history edits/clean/repair. **releaseReady=false**.

## Git, tài nguyên và bước tiếp

Review exact task scope để commit/push nhánh riêng theo quyền; không merge/force. Bốn research22/11 untracked ngoài task giữ nguyên. Source pin13files và26Face untracked/cache/model gốc giữ bytes; private credentials/config/registry/raw logs/model/venv/build ngoài Git. Cleanup36DB/108checks +repeat đạt, đúng UUID/outside-row preservation; own service/JVM/DB đã dừng, giữ volumes/schema/history. CI/CD inventory08:30UTC0workflow/run/deployment/webhook, không gọi CI pass.

Bước tiếp: cung cấp dataset có quyền sử dụng với calibration/evaluation identities/sessions/unknown cohorts tách biệt; đánh giá 1:N và PAD/attack data, quyết định threshold/liveness trước mở real admission/schema mode. Xác định kiosk source thực và nối trusted capture transport khi đủ evidence. Không tự thu người thật hoặc thay model. [Quyết định tổng hợp](DECISIONS.md), [AGENTS](../AGENTS.md).

Lịch sử: F02de82618 [enrollment evidence](backend-handover/evidence/F02_FACE_ENROLLMENT.md), F01c3eb411, renewal4af8bb8, I01d2774c9, MEMBER activation9503110, M035399c57, M0492328e0. Các test/UI lịch sử không phải lượt F03A.
