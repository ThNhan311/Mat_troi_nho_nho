# FitCenter — camera gate prototype (MVP)

Đây là demo **chọn ứng viên khuôn mặt + MOCK authentication**, không nhận diện danh tính, không kiểm tra liveness và không mở cổng thật. Chỉ chạy cục bộ; không có HTTP client, không lưu/đẩy ảnh, embedding, secret hay AttendanceRecord. Payload mock chỉ chứa metadata. Khung hình tồn tại trong RAM để preview và đo chất lượng.

Yêu cầu gốc: [implementation prompt](../docs/face/CODEX_IMPLEMENTATION_PROMPT.md) và [spec v0.3](../docs/face/FITCENTER_FACE_PROTOTYPE_SPEC.md). Kết quả đã chạy: [báo cáo kiểm thử](../docs/face/PROTOTYPE_TEST_REPORT.md).

## Cài đặt — Windows PowerShell

Chạy từ thư mục gốc repository. Đã kiểm chứng bằng Python **3.12.10 x64** trên Windows. Không cần activate virtualenv hoặc đổi ExecutionPolicy.

```powershell
py -3.12 -m venv face/.venv
.\face\.venv\Scripts\python.exe -m pip install -r face/requirements.txt
.\face\.venv\Scripts\python.exe -m pip check
.\face\.venv\Scripts\python.exe -m pytest face/tests -v --junitxml=face/test-results.xml
```

Chỉ cài một bản cung cấp `cv2`: `opencv-contrib-python`, cũng là dependency của MediaPipe. Không cài thêm `opencv-python`/`opencv-python-headless` vào cùng virtualenv. Các dependency trực tiếp được pin trong [requirements](requirements.txt); dependency gián tiếp chưa có lockfile.

## Demo không cần webcam/model

```powershell
# Preview dùng checkerboard tổng hợp và bbox giả lập; Q/Esc hoặc đóng cửa sổ để thoát.
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic

# Chạy headless có thời hạn, in số frame/detection/request và kết quả mock.
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 3
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 3 --mock-outcome REJECTED
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 3 --mock-outcome SERVICE_ERROR
.\face\.venv\Scripts\python.exe -m face.prototype.app --synthetic --headless --seconds 9 --mock-outcome TIMEOUT
```

`--mock-delay 2` mô phỏng worker chậm trong khi vòng preview vẫn chạy. Các giá trị `SUCCESS/REJECTED/TIMEOUT/SERVICE_ERROR` đều là mock. `TIMEOUT` chờ đến khi controller hủy tại deadline. Checkerboard cố tình giữ nguyên trong ROI: sau SUCCESS sẽ chỉ có một request cho đến khi kết thúc demo.

## Webcam với MediaPipe Tasks

MediaPipe **0.10.32** dùng `mediapipe.tasks.python.vision.FaceDetector` ở `RunningMode.IMAGE`, không dùng API `mp.solutions` cũ. Adapter chạy detection tối đa theo cấu hình; không gửi video lên server. Tải model riêng, không commit model vào Git:

```powershell
New-Item -ItemType Directory -Force face/models | Out-Null
Invoke-WebRequest -Uri 'https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite' -OutFile face/models/blaze_face_short_range.tflite
Get-FileHash -Algorithm SHA256 face/models/blaze_face_short_range.tflite
.\face\.venv\Scripts\python.exe -m face.prototype.app --camera 0 --model face/models/blaze_face_short_range.tflite --config face/config.example.json
```

SHA256 của model đã dùng khi kiểm thử: `b4578f35940bf5a1a655214a1cce5cab13eba73c1297cd78e1a04c2380b0152f`.

Model lấy từ [MediaPipe Face Detector](https://ai.google.dev/edge/mediapipe/solutions/vision/face_detector). Đối chiếu model card và giấy phép model/dependency trước khi phân phối. Lệnh demo không tự tải model. Thiếu model sẽ báo lỗi; không tự chuyển sang detector giả trong chế độ webcam.

Cho phép camera cho desktop apps trong Windows Settings; đóng ứng dụng khác đang giữ webcam; thử `--camera 1` nếu cần. Camera dùng DirectShow trên Windows, release khi thoát và thử mở lại mỗi 1 giây khi đọc lỗi. Màn hình cảnh báo khi camera mất kết nối; không tạo quan sát ROI trống từ lỗi camera. OpenCV/driver có thể chặn trong `VideoCapture.read()`; kiểm thử độ trễ/rút cáp trên thiết bị kiosk thực vẫn cần operator. Không có tuyên bố đã kiểm chứng webcam thật trong báo cáo hiện tại.

## Cấu hình và quy tắc

Sửa [config.example.json](config.example.json), hoặc sao chép thành một file JSON khác rồi truyền `--config <path>`. Sai/thiếu loại giá trị hoặc key lạ sẽ không được chấp nhận. Không cần sửa nghiệp vụ để đổi ngưỡng.

| Tham số | Mặc định | Ý nghĩa |
|---|---:|---|
| ROI | x=.2, y=.1, w=.6, h=.8 | Tỷ lệ frame; **tâm bbox** phải trong ROI, kể cả biên |
| min_width_ratio / min_height_ratio | .15 / .15 | Cả hai chiều bbox phải đủ lớn so với frame |
| min_blur_variance | 60 | Phương sai Laplacian trên crop grayscale |
| min_brightness / max_brightness | 45 / 220 | Độ sáng trung bình grayscale 0–255 |
| detection_hz | 8 | Preview vẫn xử lý frame ở giữa hai lần detection |
| stable_seconds / stable_min_frames | .7 / 3 | Phải đạt đồng thời thời gian và số observation |
| stable_iou | .4 | IoU giữa bbox hiện tại và trước đó để duy trì continuity |
| max_detection_gap_seconds | .4 | Quá lâu không có observation thì reset stability |
| auth_timeout_seconds | 7 | Deadline cục bộ; kết quả tại/sau deadline bị bỏ qua |
| cooldown_seconds | 5 | Áp dụng cho mọi kết quả, kể cả lỗi và timeout |
| leave_seconds | .4 | Sau SUCCESS phải thấy ROI không còn mặt qua các observation liên tục |
| reconnect_seconds | 1 | Khoảng giữa hai lần thử mở lại webcam |

`EligibleFace = SizeOK AND QualityOK AND InsideROI`. Không cộng mặt bé ở background vào số eligible. Kết quả selector có từng lý do reject (`TOO_SMALL`, `BLUR_OR_UNKNOWN`, `BRIGHTNESS_OR_UNKNOWN`, `OUTSIDE_ROI`, `INVALID_BOX`). Không có quality signal thì reject. Không ước lượng góc mặt và không có quality score giả; các ngưỡng cần hiệu chỉnh trên camera thật.

`SelectionStatus.READY` chỉ có nghĩa **một ứng viên**; `AuthStateMachine.READY` chỉ xuất hiện **sau ổn định**. Mất mặt, nhiều eligible, IoU thay đổi mạnh hoặc detection bị ngắt đều reset stability.

```text
IDLE -> READY -> VERIFYING -> COOLDOWN -> IDLE
```

Network mock chạy trên daemon worker, gửi tối đa một request, không xếp hàng request và không retry. Main thread nhận result qua mailbox có giới hạn; `request_id` duy nhất, callback lặp/trễ/sai ID bị bỏ qua. Timeout yêu cầu worker hủy; nếu transport sau này không chịu dừng, slot vẫn bận đến khi nó kết thúc, tránh request chồng nhau. Shutdown ngừng nhận kết quả, yêu cầu hủy, join tối đa .3s, đóng camera/detector/window. Real client tương lai phải có deadline và cancellation riêng, không chỉ dựa vào việc bỏ callback.

Sau SUCCESS, chỉ reset khi **không còn bất kỳ detected face nào có tâm trong ROI** trong .4s và đủ cooldown. Mặt còn trong ROI nhưng mờ/tối/nhỏ không được coi là đã rời; lỗi camera/detector cũng không phải chứng cứ rời ROI. Detector vẫn có thể bỏ sót mặt: đây là giới hạn heuristic, chưa có identity tracking. Sau thất bại có thể thử lại sau cooldown và một khoảng ổn định mới.

## Bố cục và tích hợp về sau

| Module | Trách nhiệm |
|---|---|
| [camera.py](prototype/camera.py) | Vòng đời camera, reconnect, synthetic video source |
| [detector.py](prototype/detector.py) | Protocol detector, MediaPipe Tasks adapter, mock detector, đo chất lượng |
| [selector.py](prototype/selector.py) | EligibleFace và lý do reject |
| [state_machine.py](prototype/state_machine.py) | StableFaceGate, request ID, deadline, cooldown, re-arm |
| [auth_client.py](prototype/auth_client.py) | AuthClient protocol, MockAuthClient, single-flight worker |
| [controller.py](prototype/controller.py) | Điều phối worker/result/observation trên main thread |
| [app.py](prototype/app.py) | CLI, ROI/bbox/eligible count, trạng thái và hướng dẫn |
| [types.py](prototype/types.py) / [config.py](prototype/config.py) | Hợp đồng metadata và cấu hình |
| [tests/](tests/) | Headless pytest, không cần ảnh người thật |

MVP không cung cấp liveness/enrollment/recognition thật. Payload metadata hiện tại **không đủ** làm capture protocol cho liveness. Giai đoạn 2 phải thiết kế interface capture nhiều frame/challenge theo giải pháp liveness được đánh giá, rồi mới thay mock bằng pipeline nhận diện.

Giai đoạn 3 mới đối chiếu hợp đồng `POST /check-ins/face` với backend thật, xác thực kiosk, request idempotency, membership ACTIVE và ghi AttendanceRecord trong transaction. Quét trùng **30 phút** có thể mời vào khi vẫn đủ quyền nhưng không tạo record mới; 30 phút không phải camera cooldown. Enrollment chỉ Admin tại gym, có xác minh và consent; mỗi Member một FacialProfile ACTIVE; đăng ký lại phải có audit và chỉ thay mẫu cũ khi mẫu mới thành công. Không thay Spring Boot, database hoặc Flutter trong nhánh này.

## Kiểm tra thủ công còn cần làm

1. Trên kiosk được phép thử nghiệm, mở preview với model, xác nhận ROI/bbox/hướng dẫn; Q/Esc và nút đóng cửa sổ giải phóng camera.
2. Xác nhận 0, 1 và 2 mặt đủ điều kiện, mặt nhỏ phía sau, mờ/tối/ngoài ROI; điều chỉnh ngưỡng theo thiết bị.
3. SUCCESS mock rồi giữ nguyên trong ROI hơn 5s: không gửi lại; rời ROI rồi quay lại: được thử sau cooldown và ổn định.
4. Rút/cắm webcam, kiểm tra cảnh báo và reconnect; đo preview FPS, detection latency và false selection bằng quy trình có consent. Không commit hoặc upload dữ liệu sinh trắc học.

Chỉ push/mở draft PR sau khi người dùng đã duyệt diff và kết quả test theo implementation prompt. Không merge vào main.
