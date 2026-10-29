# FITCENTER — Face Recognition Prototype

**Phiên bản:** 0.3 (bản giao triển khai Codex)  
**Phạm vi:** Kiosk camera, Face Selection, state machine, các interface cho Recognition/Liveness, test và tài liệu tích hợp  
**Trạng thái:** Đặc tả triển khai thử nghiệm; chưa phải phê duyệt để dùng dữ liệu sinh trắc học thực tế.

## 1. Bối cảnh và ranh giới

Repository: `ThNhan311/Mat_troi_nho_nho` (private). Những nhánh đã biết tại thời điểm trao đổi: `main`, `backend`, `feature/database-schema`, `frontend`, `chore/setup-mobile`, `old`. Nhánh `frontend` có các project Flutter (`fitcenter_ad`, `fitcenter_member`, `fitcenter_pt`, `fitcenter_kiosk`), nhưng **không giả định** chúng đã tích hợp hoặc chạy được. Backend Spring Boot/Java và PostgreSQL có thể chưa merge, nên prototype phải chạy độc lập.

Tài liệu đề tài gốc thống nhất: đăng ký khuôn mặt tại phòng gym trong/tiếp sau kích hoạt hội viên lần đầu; Member + Gym Camera/Kiosk là actors check-in; membership phải ACTIVE; chỉ ghi `AttendanceRecord` khi match thành công và không trùng trong **30 phút**; nếu quét lặp trong cửa sổ này có thể mời vào nhưng **không tạo bản ghi mới**. `30 phút` là business duplicate window, **không phải** cooldown của camera.

### Phạm vi triển khai đợt 1 (MVP)
1. Dùng webcam trên Windows để preview liên tục ở máy kiosk; giải phóng camera khi đóng.
2. Phát hiện khuôn mặt bằng detector có adapter (ưu tiên MediaPipe; kiểm tra API/version thực tế).
3. Lọc khuôn mặt theo `EligibleFace = SizeOK AND QualityOK AND InsideROI`.
4. Đếm **chỉ những mặt đủ điều kiện**: 0 → hướng dẫn; 1 → ổn định rồi READY; >=2 → MULTIPLE_ELIGIBLE_FACES.
5. State machine: `IDLE -> READY -> VERIFYING -> COOLDOWN -> IDLE`. Không gửi frame/yêu cầu mới trong VERIFYING; mỗi kiosk tối đa 1 request đang xử lý.
6. Preview/detection cục bộ tiếp tục được phép trong khi VERIFYING; không upload/stream liên tục. Gửi **một yêu cầu xác thực** sau khi đã lấy đủ frame/capture cần thiết; không mặc định 1 ảnh tĩnh đủ cho liveness.
7. Sau response hoặc timeout vào COOLDOWN **5 giây** (cấu hình được). Sau thành công, yêu cầu khuôn mặt rời ROI trước khi tái kích hoạt, tránh một người bị gửi lặp lại.
8. API client mock/stub cho xác thực, với `request_id`, timeout, callback/result, xử lý kết quả về trễ và lỗi mạng. Không tự mô tả mock là xác thực thật.
9. Tests tự động cho selector và state machine, bao gồm race/timeout, cùng README hướng dẫn Windows.

### Không thuộc đợt 1
- Không nhận diện danh tính thật, không lưu embedding/ảnh sinh trắc học, không triển khai liveness thực.
- Không thay schema/migration, không tự sửa Spring Boot hoặc Flutter, không mở cổng gym thật.
- Không đưa hình ảnh hội viên, token, mật khẩu, database dump lên Git hoặc dịch vụ AI.

Đợt 2 mới bổ sung liveness chuyên biệt, enrollment/embedding/1:N identification và bộ đánh giá sai số với dữ liệu có sự đồng ý; đợt 3 mới ghép Spring Boot và cơ sở dữ liệu sau review schema/API.

## 2. Business Rules

| Mã | Quy tắc |
|---|---|
| BR-FR-01 | Chỉ Admin được phân quyền đăng ký khuôn mặt **tại phòng gym**, sau khi xác minh danh tính Member và ghi nhận đồng ý xử lý sinh trắc học. Member không được tự enrollment tại nhà. |
| BR-FR-02 | Mỗi Member chỉ có **một FacialProfile ACTIVE** tại một thời điểm; profile có thể chứa nhiều embedding của chính Member. Kiểm tra khả năng đăng ký trùng danh tính. |
| BR-FR-03 | Đăng ký lại phải được Admin xác minh tại gym, ghi audit; chỉ vô hiệu hóa mẫu cũ sau khi mẫu mới được tạo/kích hoạt thành công; lỗi giữa chừng không làm hỏng trạng thái. |
| BR-FR-04 | `EligibleFace = SizeOK AND QualityOK AND InsideROI`. Loại các mặt không đủ điều kiện khỏi danh sách ứng viên; nếu 0/1/>=2 thì hướng dẫn/tiếp tục/báo lỗi tương ứng. |
| BR-FR-05 | Membership ACTIVE + face match hợp lệ + không có AttendanceRecord trùng trong 30 phút → tạo **đúng một** record; quét trùng trong 30 phút → mời vào (khi vẫn đủ điều kiện truy cập), **không thêm record**. |
| BR-FR-06 | Tối đa một authentication request in-flight trên một kiosk. |
| BR-FR-07 | Trong `VERIFYING`, không gửi thêm ảnh, frame hoặc authentication request lên server. |
| BR-FR-08 | Kết thúc request (thành công, thất bại hoặc timeout) chuyển `COOLDOWN` 5 giây cấu hình được. |
| BR-FR-09 | Chỉ gửi request nếu có đúng một EligibleFace ổn định trong nhiều frame hoặc đủ thời gian theo cấu hình. |
| BR-FR-10 | Gắn `request_id` duy nhất cho mỗi lần xác thực; kết quả trễ sau timeout bị bỏ qua ở kiosk; backend phải có idempotency khi tích hợp thật. |

## 3. Face Selection

- `SizeOK`: dùng kích thước bbox theo tỷ lệ frame hoặc pixel (config), không cố định ngưỡng dựa vào một máy quay duy nhất.
- `QualityOK`: tối thiểu sử dụng các tín hiệu có thể đo được (ví dụ độ mờ/blur, độ sáng, góc mặt nếu model hỗ trợ). Nếu không có ước lượng đáng tin cho một tiêu chí, ghi rõ hạn chế; không gán quality score giả và coi là production-ready.
- `InsideROI`: quy định rõ dùng tâm khuôn mặt hay tỷ lệ giao bbox/ROI, cấu hình ROI theo tỷ lệ khung hình. Vẽ vùng ROI trên preview.
- `EligibleFace` chỉ là bộ lọc **ứng viên**, không thay thế kiểm tra liveness hoặc identity.
- Nên sử dụng hysteresis/stability, chống trạng thái giật giữa READY/IDLE khi bbox dao động.

## 4. State machine và luồng bất đồng bộ

```text
IDLE --[exactly 1 eligible face stable]--> READY
READY --[auth request accepted locally]--> VERIFYING
READY --[face lost / multiple eligible]--> IDLE
VERIFYING --[success / rejected / error / timeout]--> COOLDOWN
COOLDOWN --[5s elapsed; rearm policy satisfied]--> IDLE
```

- Camera preview không bị block bởi network call; worker/thread/async callback truyền result về UI thread an toàn.
- Có `request_id`, timeout, bounded queue hoặc **không xếp hàng request**; drop stale results; không dùng retry mù khiến double-record.
- Sau success: re-arm khi face đã rời ROI (có thể áp dụng cooldown tối thiểu trước), tránh kiosk cùng người gửi cứ 5 giây/lần.
- Sau fail: cho thử lại theo chính sách nhưng không phá giới hạn một request in-flight.
- Khi `shutdown`: cancel/ignore task, đóng webcam, giải phóng resources.

## 5. Tham số khởi đầu để hiệu chỉnh

| Cấu hình | Giá trị thử nghiệm |
|---|---|
| Preview | 15–30 FPS tùy webcam |
| Detection frequency | 5–10 Hz, không nhất thiết trên mọi frame |
| Stable duration | 0.5–1.0 giây |
| Authentication timeout | 5–10 giây |
| Cooldown | 5 giây |
| Requests in flight | 1/kiosk |
| Attendance duplicate window | 30 phút — sau này xử lý ở Spring Boot |

Các giá trị là giả định thử nghiệm; cần đo độ trễ, FPS và tỷ lệ false selection với thiết bị thật.

## 6. Cấu trúc đề xuất (Codex được điều chỉnh nếu repo khác)

```text
face/
  prototype/
    app.py                 # entrypoint kiosk UI/demo
    config.py              # config/ROI/timing/thresholds
    camera.py              # capture resource lifecycle
    detector.py            # MediaPipe adapter
    selector.py            # EligibleFace decision
    state_machine.py       # IDLE/READY/VERIFYING/COOLDOWN
    auth_client.py         # stub/mock initially
    types.py               # typed outcomes
  tests/
    test_selector.py
    test_state_machine.py
    test_auth_flow.py
  requirements.txt (hoặc pyproject.toml)
  README.md
```

Không sửa/xóa code khác chỉ để khớp cấu trúc minh họa.

## 7. Interface và kết quả minh họa (mock, không phải kết quả xác thực thật)

Input của `FaceSelector`: frame dimensions, ROI, face bboxes, measurable quality signals. Output: `eligible_faces`, `rejection_reasons`, `status = NO_ELIGIBLE_FACE | READY | MULTIPLE_ELIGIBLE_FACES`.

Input của `AuthClient`: `request_id`, capture payload (chỉ mock ở MVP), kiosk/device id; output `SUCCESS | REJECTED | TIMEOUT | SERVICE_ERROR` + `request_id`. `SUCCESS` mock **không được** tạo AttendanceRecord thực.

Hợp đồng tích hợp về sau: Spring Boot/Kiosk `POST /check-ins/face` (tài liệu gốc), có service credentials; backend nhận kết quả từ Face Service và xác minh account, membership, dedupe window 30 phút trong transaction. Tên endpoint thực tế phải đối chiếu code trước khi triển khai. Quy tắc repeated scan: UI có thể chào mừng nhưng không ghi `AttendanceRecord` thứ hai.

## 8. Test cases và điều kiện nghiệm thu MVP

| Test | Tình huống | Mong đợi |
|---|---|---|
| T01 | Không có khuôn mặt | NO_ELIGIBLE_FACE |
| T02 | Một mặt đạt đủ 3 điều kiện trong ROI | READY sau ổn định |
| T03 | Mặt quá nhỏ, dù sắc nét | Không eligible |
| T04 | Một mặt lớn trước, mặt nhỏ phía sau | Chỉ một eligible |
| T05 | Hai mặt đủ điều kiện | MULTIPLE_ELIGIBLE_FACES; không auth |
| T06 | Mặt lớn nhưng mờ/quá tối | Không eligible |
| T07 | Mặt ngoài ROI | Không eligible |
| T08 | Face xuất hiện chập chờn trước stable threshold | Không gửi auth |
| T09 | Trong VERIFYING có thêm frame và người khác | 0 request mới |
| T10 | Auth timeout | COOLDOWN; stale result bị bỏ qua |
| T11 | Auth thành công và face không rời ROI | Không auto-auth lại mỗi 5 giây |
| T12 | Auth thành công, face rời ROI rồi người mới đến | Có thể tái xác thực sau cooldown |
| T13 | Webcam ngắt giữa chừng | Cảnh báo, không crash và giải phóng hợp lệ |
| T14 | 2 callbacks cùng request_id | Chỉ xử lý một lần |
| T15 | Server mock trả lỗi | Phản hồi an toàn, không khóa kẹt |
| T16 | Ngưỡng thay đổi qua config | Không cần sửa code nghiệp vụ |

Sau MVP, bổ sung test liveness thật, identification accuracy, membership EXPIRED, dedupe trong 30 phút, concurrent duplicate requests, consent và quyền Admin tại gym. Không đánh dấu PASS cho các test chưa chạy.

## 9. Definition of Done

- Webcam preview hoạt động hoặc cung cấp mock video source để CI/headless chạy tests.
- Unit tests selector/state-machine/auth-flow chạy PASS trong môi trường hiện có.
- README có các lệnh cài đặt/chạy/test bằng PowerShell trên Windows, nêu phụ thuộc model/download nếu có.
- Không commit ảnh sinh trắc học, secret, `.env`, `.venv`, cache/model nặng không được phép.
- Có báo cáo `docs/face/PROTOTYPE_TEST_REPORT.md`: ngày chạy, branch/commit, môi trường, câu lệnh, test passed/failed/skipped, evidence thực và known limitations.
- Không tự merge vào main. Khi muốn push/PR, xem chính sách của nhóm và kiểm tra thay đổi trước.

## 10. Phụ thuộc và rủi ro cần báo cáo

- Repo có nhánh backend, database, Flutter chưa hợp nhất: triển khai đợt 1 **độc lập**, không tự merge.
- Liveness thực và face identification phải được đánh giá riêng; demo EligibleFace không được gọi là Face Recognition hoàn chỉnh.
- Camera permissions, quyền riêng tư, model license và dữ liệu đồng ý cần được giải quyết trước thử nghiệm người thật.
- Khi CI không có webcam, chạy unit tests bằng synthetic bboxes hoặc mocks; không giả báo đã kiểm thử camera thực.
