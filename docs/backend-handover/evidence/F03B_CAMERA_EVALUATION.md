# F-03B — Camera/evaluation preparation, 24/11/2026

Base F03A `70ca11ce4eee068b1b25147e829b0d804e105a53`; branch `feature/face-camera-evaluation`. Evidence gắn working tree trước commit đóng; SHA commit xem Git history. [11 source hashes/provenance](F03B_SOURCE_HASHES.json), [kết quả máy đọc](F03B_RESULTS.json), [operator quickstart](../25_FACE_CAMERA_EVALUATION_QUICKSTART.md), [contract](../decisions/2026-11-24_F03B_CAMERA_EVALUATION.md).

## Đã làm

Capture local preview mirror/ảnh raw, quality ROI/size/blur/brightness/stability dùng code hiện có; không inference trước consent. Consent xác nhận tương tác, R + Space từng still, tự disarm/pause khi lỗi, chống stale frame; không auto-save/video/upload. Subject/session/operator/consent UUID và source/hashes private ngoài mọi Git worktree. Không gọi service/Backend hoặc mở admission.

Kế hoạch identity split tạo trước, gallery/probe khác session, unknown probe-only. Seal kiểm integrity/ảnh/hash/pixel/session/consent, calibration chỉ tính trên calibration, freeze từ báo cáo calibration và evaluate không override hoặc ghi đè. Runtime kiểm đúng SHA buffalo_s, model/source/preprocessing/dependencies được khóa. Không chọn threshold production. CLI evaluation F03A trực tiếp bị chặn; metrics cũ tái sử dụng, không mở rộng synthetic protocol mới.

Camera/detector import **nguyên byte** từ Face `fcabeba765d6e597cbc5fbed76fafc08f9604e03`;8 file mới trong evaluation,1 CLI sửa =11 file executable/source/test. Hai file import chứa cả helper synthetic nguyên bản nhưng CLI operational không cung cấp synthetic mode. 26 file Face untracked/cache/model gốc đối chiếu hash không đổi;4 research ngoài task giữ nguyên. Không executable Java/SQL/Dart hoặc migration/default gate đổi.

## Kiểm thử thực chạy trên source cuối

| Suite | Passed | Failed | Errors | Skipped |
|---|---:|---:|---:|---:|
| Repo Python regression:43 F03B +31 service/evaluator +27 F01 addon |101|0|0|0|
| Pinned Face camera/selector/state/auth, private export |47|0|0|1|

Repo report bắt đầu `2026-11-24T23:39:30+07:00`,34.512s; pinned report `23:37:18+07:00`,0.208s. Focused trước đó là subset, không cộng. JUnit/raw logs private ngoài Git, SHA reports trong JSON. Manual skip `test_T13_physical_webcam_manual` cần operator kiểm preview/rút cắm thật, giữ nguyên skip. GUI-loop tests mock window/keyboard và dùng ảnh generated, **không phải GUI camera thật**.

Commands (tại worktree, explicit isolated Python3.12, `PYTHONDONTWRITEBYTECODE=1`):

```powershell
& $python -m pytest face/evaluation/tests face/service_v2/tests face/integration/tests `
  --rootdir=. -p no:cacheprovider -q --junitxml="$private/regression-final.xml"
# Chạy riêng tại private/pinned_tests, PYTHONPATH=worktree:
& $python -m pytest test_camera.py test_selector.py test_state_machine.py test_auth_flow.py `
  --rootdir=. -p no:cacheprovider -q --junitxml="$private/pinned-regression.xml"
```

Pinned tests/conftest export bằng `git show fcabeba...:face/tests/<file>`; không sửa decorator skip hoặc gộp C:/D: test paths. Tests mới kiểm consent/no-write, one-shot/pause/stale/release, mirror giữ nguyên raw, ROI/quality/stability, role/session/consent binding, hash/pixel duplicate, orphan, giữ file khác khi rollback/collision, sealed source/dataset integrity, no evaluation override/retune, source/data đổi giữa inference. Review đã siết cleanup chỉ file tự tạo khi UUID collision và yêu cầu terminal tương tác; các ca này đạt ở lượt cuối. Dữ liệu noise/checkerboard và engine giả chỉ trong unit tests, không báo thành accuracy.

## Camera/runtime thực tế — tách khỏi unit tests

Windows inventory thấy **Integrated Camera / Camera / OK**. DirectShow index0 đọc3 frame **640×480 BGR**, giải phóng thành công, không lưu ảnh, không inference, không hiển thị preview. CLI camera probe được chạy lại cùng kết quả loại này; không đếm thành accuracy/UI scenarios khác. Elapsed khoảng1375ms gồm mở/đọc camera, **không phải latency nhận diện**.

Isolated Python3.12/OpenCV4.11/ONNXRuntime1.31.1/InsightFace2.1/NumPy2.2.6, buffalo_s SCRFD/ArcFace đúng hai SHA F03A. Actual model load + capture detector trên ảnh đen generated 480×640 trả0box, guidance NO_FACE/not-ready. Không lưu ảnh người/embedding mới, không chạy nhận diện người thật. Dependencies và model hashes trong JSON; không sửa venv/cache gốc.

**Chưa chạy:** camera preview/mirror/unplug trực quan, ảnh người có consent, calibration/evaluation biometric, PAD/liveness, camera-to-Backend admission. Không có authorized dataset nên genuine/impostor/FNIR/FPIR/latency biometric là `null`, không dùng số unit-test làm kết quả thật. `NOT_PERFORMED`, admission false và release gates giữ nguyên. Backend1106 của F03A là lịch sử, không rerun/không tính là F03B; Flutter/DB không thay nên không chạy lại.

## Review, tài nguyên và phần người vận hành phải làm

Chỉ source/tests/docs/sanitized aggregate evidence; không dataset/ảnh/vector/consent record/manifest cá nhân/credential/raw logs/SDK/cache/model/build. Quickstart chỉ chứa tên trường/biến, không secret. Diff review giữ code production Backend, migrations và original Face. Không khởi động Backend/DB/service; camera probe đã close, unit camera là mocks. Không broad cleanup hay tác động volume/process đồng đội; generated unit fixtures/reports riêng ngoài Git.

Fetch/remote/worktrees đã kiểm; GitHub CI inventory `16:43:19Z`:0workflow/run/deployment/webhook, **không phải CI pass**. Push chỉ nhánh riêng sau review, không merge/force. Cần operator chọn participant/consent/retention/splits, kiểm preview/rút cắm, tự chụp gallery và probe ở các phiên thật khác nhau, rồi calibration→freeze→evaluation theo quickstart. F03 thật chưa hoàn tất; chưa có PAD/threshold production hoặc quyền vào gym.
