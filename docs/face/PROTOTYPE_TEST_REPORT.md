# FitCenter Face Prototype — báo cáo kiểm thử MVP

## Phiên chạy và phạm vi

- Ngày: **2026-10-29**, múi giờ Asia/Saigon (UTC+07).
- Repository: `ThNhan311/Mat_troi_nho_nho`.
- Nhánh: `feature/face-prototype-camera-gate`.
- Base đã fetch: `origin/main` tại **`5c8693bfaeb4c0e85f4c7bcb21c5fd487dad3516`**.
- Revision kiểm thử: working tree của implementation trên base này trước khi tạo commit; lấy commit chứa implementation/báo cáo bằng `git log -1 --format=fuller -- docs/face/PROTOTYPE_TEST_REPORT.md`. Không tuyên bố đã test một commit hash chưa tồn tại khi chạy tests.
- Working tree sạch trước thao tác nhánh. Ban đầu ở `frontend`; `main` cục bộ có thêm `e6457f1` (`Add four Flutter frontend projects`). Đã chạy `git fetch origin`, `git switch main`, `git pull --ff-only origin main`, sau đó **tạo feature trực tiếp từ `origin/main`** để tránh mang commit Flutter đó. Giữ nguyên `main` cục bộ và các nhánh khác. Sau đó fetch/prune remote refs; không merge/rebase/reset/stash.
- Nhánh feature đã bỏ upstream `origin/main` do Git tự gán khi tạo từ remote ref, tránh nhầm đích publish. Chưa push hoặc mở PR; chưa merge.
- Chỉ thêm module độc lập trong [face/](../../face/) và tài liệu trong thư mục này. [Hai tài liệu](CODEX_IMPLEMENTATION_PROMPT.md) [nguồn](FITCENTER_FACE_PROTOTYPE_SPEC.md) được sao chép nguyên nội dung từ FitCenter.zip.

## Môi trường và kết quả thật

| Thành phần | Giá trị đã quan sát |
|---|---|
| OS | `Windows-11-10.0.26200-SP0`, win32 |
| Python | 3.12.10 x64, virtualenv cục bộ |
| pytest | 8.4.2 |
| MediaPipe | 0.10.32 — Tasks API |
| OpenCV | cv2 4.11.0, distribution opencv-contrib-python 4.11.0.86 |
| NumPy | 2.2.6 |
| Model | BlazeFace short range float16 v1, tải từ host MediaPipe chính thức |
| Model SHA256 | `b4578f35940bf5a1a655214a1cce5cab13eba73c1297cd78e1a04c2380b0152f` |

Các lệnh đã chạy từ root repository:

```powershell
.\face\.venv\Scripts\python.exe -m pytest face/tests -v --junitxml=face/test-results.xml
.\face\.venv\Scripts\python.exe -m compileall -q face/prototype face/tests
.\face\.venv\Scripts\python.exe -m pip check
```

Kết quả runner cuối sau khi thêm UI lifecycle tests:

```text
collected 56 items
SKIPPED [1] face\tests\test_camera.py:59:
  Manual Windows webcam preview/unplug check requires operator and physical device; mocks tested in T13
55 passed, 1 skipped in 1.26s
No broken requirements found.
```

Exit code 0 cho pytest, compileall và pip check. Đây là lượt chạy lại sau khi review và sửa kiểm tra ROI chạm mép frame (T16); lượt trước sửa đạt 55 passed, 1 skipped trong 1.03s. JUnit được xuất tại `face/test-results.xml` cục bộ và được gitignore; chạy lại lệnh trên để tạo evidence mới. Không commit virtualenv/model/cache/XML sinh ra. Lượt trước khi thêm bốn UI tests: 51 passed, 1 skipped trong 6.64s; số liệu cuối là 55/1, không cộng gộp các lượt.

Review diff giữ nguyên hai hard line break Markdown (hai dấu cách cuối dòng) có sẵn trong spec nguồn; whitespace check cho code, tests và tài liệu mới được chạy riêng, không sửa bản spec gốc chỉ để bỏ định dạng này.

## Ma trận T01–T16

PASS bên dưới chỉ áp dụng cho phạm vi unit/mock/synthetic đã chạy, không tương đương nghiệm thu thiết bị thực hoặc sinh trắc học.

| ID | Kết quả | Evidence từ pytest / điều đã xác nhận |
|---|---|---|
| T01 | PASS | `test_T01_no_face`: không bbox → NO_ELIGIBLE_FACE |
| T02 | PASS | `test_T02_ready_only_after_stability`: chưa đủ .7s không auth; .75s với 7 observation → READY rồi VERIFYING |
| T03 | PASS | `test_T03_small_face`: bbox nhỏ, đủ sáng/nét vẫn bị TOO_SMALL |
| T04 | PASS | `test_T04_large_front_small_background`: 1 mặt lớn + 1 nhỏ → đúng 1 eligible |
| T05 | PASS | `test_T05_two_eligible_no_auth`: MULTIPLE_ELIGIBLE_FACES, không tạo request |
| T06 | PASS | `test_T06_bad_quality` (5 biến thể): mờ, tối, quá sáng, thiếu signal, NaN bị reject; test đo thực trên frame đen cũng PASS |
| T07 | PASS | `test_T07_outside_roi`: tâm ngoài ROI bị reject |
| T08 | PASS | `test_T08_flicker_no_auth`: mặt xuất hiện/mất xen kẽ không đủ ổn định |
| T09 | PASS | `test_T09_verifying_single_flight` và `test_T09_preview_observations_continue_while_worker_blocked`: quan sát tiếp tục khi worker bị chặn, không gửi request thứ hai |
| T10 | PASS | `test_T10_timeout_stale_ignored`, `test_T10_timeout_keeps_slot_until_old_transport_exits`, `test_T10_mock_timeout_cancellable`: timeout → COOLDOWN, không nhận SUCCESS cũ, không chồng worker kể cả sau cooldown |
| T11 | PASS | `test_T11_success_face_stays_no_repeat`: giữ mặt trong ROI qua nhiều cửa sổ cooldown không auth lại |
| T12 | PASS | `test_T12_leaves_then_returns_can_auth`: ROI trống liên tục .4s, đủ 5s cooldown rồi ổn định → request ID mới |
| T13 | PASS (mock); SKIPPED (webcam thật) | 4 tests mock PASS: đọc lỗi/exception, open thất bại, factory lỗi; reconnect theo khoảng, release đúng một lần. `test_T13_physical_webcam_manual` SKIPPED; chưa rút/cắm thiết bị thật |
| T14 | PASS | `test_T14_duplicate_callback_only_once`: callback thứ hai bị bỏ qua, không kéo dài cooldown |
| T15 | PASS | `test_T15_mock_outcomes_on_worker` (SUCCESS/REJECTED/SERVICE_ERROR), `test_T15_worker_exception_recovers`, `test_T15_error_recovery`: không khóa kẹt; cho thử lại sau cooldown khi thất bại |
| T16 | PASS | `test_T16_thresholds_loaded_from_json`, `test_T16_timing_from_config`: đổi ROI/size/stability/timeout/cooldown qua config, không sửa nghiệp vụ |

Test files: [selector](../../face/tests/test_selector.py), [state machine](../../face/tests/test_state_machine.py), [auth flow](../../face/tests/test_auth_flow.py), [camera](../../face/tests/test_camera.py), [detector](../../face/tests/test_detector.py), [app lifecycle](../../face/tests/test_app.py).

Bổ sung đã PASS: quality loss/camera mất không được coi là face rời ROI; gap hoặc bbox nhảy reset stability; READY quá hạn không tạo request; deadline thắng callback đến tại deadline; shutdown bỏ callback và observations; Tasks adapter chuyển/clip bbox và close; model thật xử lý một frame đen tổng hợp không có detection. Không suy ra độ chính xác detection từ frame đen.

UI tests monkeypatch `imshow/waitKey/getWindowProperty`: xác nhận pixel ROI, thoát bằng Q/đóng cửa sổ và giải phóng nguồn tổng hợp; lỗi detector không tạo auth; lỗi khởi tạo vẫn shutdown controller. **Chưa kiểm tra bằng mắt cửa sổ preview trên desktop thật.**

## Demo end-to-end headless đã chạy

```powershell
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 2.5 --mock-outcome SUCCESS
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 2.5 --mock-outcome REJECTED
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 2.5 --mock-outcome SERVICE_ERROR
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 9 --mock-outcome TIMEOUT
```

| Kết quả mock | Frames | Detections | Elapsed (s) | Requests sent |
|---|---:|---:|---:|---:|
| SUCCESS | 72 | 18 | 2.515 | 1 |
| REJECTED | 72 | 18 | 2.516 | 1 |
| SERVICE_ERROR | 72 | 18 | 2.515 | 1 |
| TIMEOUT | 258 | 65 | 9.000 | 1 |

Tất cả exit code 0. Đây là counter đo từ vòng lặp synthetic có pacing 30Hz; không phải FPS/latency benchmark của camera hoặc model. Không đo false selection rate hoặc độ trễ phần cứng.

## Hạn chế và phần chưa làm

- **BLOCKED nghiệm thu phần cứng**: cần operator và webcam kiosk được phép thử; chưa kiểm tra preview thực, ánh sáng/góc/cự ly thật, rút/cắm dây hoặc quyền Windows camera. OpenCV/driver có thể block trong `read()`; deadline controller không thể chạy trong lúc main thread bị driver chặn.
- Không có nhận diện danh tính, embedding, enrollment, liveness, anti-spoof, FAR/FRR hoặc pose estimation. Blur/brightness và IoU chỉ là heuristic chọn ứng viên; detector bỏ sót có thể khiến re-arm sai. Chưa dùng ảnh người thật.
- Chỉ kiểm chứng model trên ảnh tổng hợp; cần review model card/license và hiệu chỉnh ngưỡng trước thử nghiệm có consent.
- Không tích hợp Spring Boot, database, Flutter, credential hoặc endpoint thật; không có AttendanceRecord hay access control thật. Dedup 30 phút, membership ACTIVE, quyền Admin, consent/audit là yêu cầu cho giai đoạn tích hợp, **chưa được test trong MVP**.
- Mock SUCCESS chỉ là nhãn mô phỏng. Capture metadata hiện tại không đủ để xác thực sinh trắc học/liveness.
- Worker không thể cưỡng bức dừng Python thread; timeout gửi cancel và giữ single-flight slot đến khi transport kết thúc. Transport thật phải hỗ trợ deadline/cancel và backend phải idempotent theo request_id.
- Dependencies trực tiếp đã pin, chưa lock toàn bộ dependencies gián tiếp. Không cần model để chạy unit tests; model smoke test sẽ SKIPPED nếu model chưa được tải ở máy mới.

## Prompt đề xuất cho giai đoạn 2 (sau khi MVP được duyệt)

> Đọc spec FitCenter và báo cáo MVP, giữ nguyên business rules. Khảo sát nhánh/API hiện hành, tạo nhánh riêng từ base nhóm đã duyệt; không merge các nhánh khác. Đề xuất trước hợp đồng capture/liveness (nhiều frame hoặc challenge theo model), enrollment tại gym do Admin xác minh và ghi consent/audit, một FacialProfile ACTIVE/Member và thay mẫu an toàn khi đăng ký lại. So sánh giải pháp nhận diện/liveness, license và yêu cầu thiết bị; thiết kế bộ đánh giá FAR/FRR, spoof và false selection trên dữ liệu có sự đồng ý, không commit/upload biometrics. Chỉ triển khai sau khi hợp đồng và kế hoạch dữ liệu được duyệt. Giữ single-flight, timeout, request_id và re-arm của MVP. Chưa ghép Spring Boot/AttendanceRecord hoặc mở cổng thật; giai đoạn 3 mới đối chiếu membership ACTIVE, idempotency và dedupe 30 phút trong transaction. Báo cáo đúng các test/đo thực tế và yêu cầu duyệt diff trước push/draft PR.
