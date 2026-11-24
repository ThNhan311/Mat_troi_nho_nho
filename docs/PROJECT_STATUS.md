# FitCenter — trạng thái tiếp tục

Cập nhật24/11/2026 tại worktree Mat_troi_nho_nho-booking-integration; branch **feature/face-camera-evaluation**, HEAD/base trước commit đóng **70ca11ce4eee068b1b25147e829b0d804e105a53**. Git là thực tế; SHA commit chứa file này xem history, không tự ghi SHA của chính nó.

## F03B — công cụ camera/evaluation đã chuẩn bị; dữ liệu thật chưa đánh giá

Đã thêm capture local preview mirror/ảnh raw, consent tương tác và R+Space cho từng ảnh; ROI/quality/stability dùng source Face hiện có. Dataset/source/consent refs/session ẩn danh ngoài Git. Plan trước thu, known/unknown và independent gallery/probe sessions; seal→calibrate→freeze→evaluate, không override threshold hoặc tune trên evaluation. Tái sử dụng buffalo_s detector/embedder và metrics F03A; không model/weights mới hoặc synthetic protocol mở rộng. [Operator quickstart](backend-handover/25_FACE_CAMERA_EVALUATION_QUICKSTART.md), [contract](backend-handover/decisions/2026-11-24_F03B_CAMERA_EVALUATION.md).

Thực chạy trên source cuối: **101 repo Python tests passed,0failed/errors/skipped** (43F03B+31service/evaluator+27F01addon); pinned Face camera/selector/state/auth **47passed,0failed/errors,1manual webcam skip**. Focused là subset, không cộng. Camera thực DirectShow index0 đọc3frame640×480,0ảnh lưu/không inference/không preview, released. Actual pinned model/capture detector trên generated black frame trả NO_FACE. Không dữ liệu người thật/biometric accuracy/PAD/visual webcam UI; không dùng số synthetic làm accuracy. [Evidence/limits](backend-handover/evidence/F03B_CAMERA_EVALUATION.md), [results](backend-handover/evidence/F03B_RESULTS.json), [11source hashes](backend-handover/evidence/F03B_SOURCE_HASHES.json).

## Git và phạm vi chưa commit tại lúc cập nhật

11source/test files:8mới evaluation,2camera/detector import nguyên pinfcabeba,1F03A CLI evaluation được guard; cùng docs/quickstart/decisions/evidence/status cho F03B. Exact file list xem Git status/diff, chuẩn bị review/commit/push nhánh riêng theo quyền đã giao. Không merge/force. 4research22/11 untracked ngoài task giữ nguyên,26Face untracked/cache/model gốc hash không đổi. Không Java/Dart/SQL/default gates/migrations thay đổi; private reports/runtime/model/fixtures ngoài Git, không stage.

## Gates, tài nguyên và bước tiếp

`liveness=NOT_PERFORMED`, admission=false, productionThresholdApproved=false. Chưa preview/unplug trực quan, chưa capture gallery/probe người thật hoặc authorized dataset, chưa calibration/evaluation/PAD/camera admission. Người vận hành cần tự chuẩn bị consent/retention/split và thực hiện từng bước camera; không tự bật ghi hình. Không gọi F03 hoàn tất. Completion/Booking/Membership/payment/activation không thay đổi.

Không Backend/DB/service khởi động bởi F03B, camera IOprobe đã release, unit GUI là mocks. Không DB/volume/resource chung bị đổi. GitHub CI inventory24/11 `16:43:19Z`:0workflow/run/deployment/webhook, không gọi CI pass. Candidate migration1–6,8–13/default-off giữ nguyên, V7 Duy558fb03 vẫn quarantine/shared history chưa biết; **releaseReady=false**.

F03A `70ca11c`: [service evidence](backend-handover/evidence/F03A_FACE_SERVICE.md), [quickstart](backend-handover/24_FACE_SERVICE_QUICKSTART.md); Backend1106/Python80 và F02/F01/UI trước là **lịch sử**, không phải lượt F03B. [Quyết định tổng hợp](DECISIONS.md), [AGENTS](../AGENTS.md).
