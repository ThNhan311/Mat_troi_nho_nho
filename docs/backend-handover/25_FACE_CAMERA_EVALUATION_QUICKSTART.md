# F-03B — Camera và đánh giá cục bộ có consent

[Contract](decisions/2026-11-24_F03B_CAMERA_EVALUATION.md) · [Evidence](evidence/F03B_CAMERA_EVALUATION.md) · [F03A runtime/service](24_FACE_SERVICE_QUICKSTART.md).

Đây là công cụ thu ảnh thủ công và đánh giá offline, **không enrollment hoặc cấp quyền vào gym**. Liveness luôn `NOT_PERFORMED`. Không có threshold production được phê duyệt. Các lệnh thu mẫu/accuracy dưới đây là hướng dẫn cho người vận hành, chưa phải kết quả đã chạy với người thật.

## 1. Runtime đã kiểm tra

Mở PowerShell tương tác tại worktree tích hợp. Dùng runtime/model F03A hiện có, không sửa PATH hay cache Face gốc:

```powershell
$python = "$env:LOCALAPPDATA/Temp/fitcenter-face-service-20261124-private/venv/Scripts/python.exe"
$modelRoot = "$env:LOCALAPPDATA/Temp/fitcenter-face-service-20261124-private/model-root"
$env:PYTHONDONTWRITEBYTECODE='1'
$env:PYTHONUTF8='1'
& $python -m face.service_v2 --probe $modelRoot
& $python -m face.evaluation.capture --probe-camera --camera 0
```

Đường dẫn trên là môi trường đã kiểm tra trên máy này; nếu không còn, khôi phục runtime từ lock/artifact bootstrap trong quickstart F03A vào **thư mục công cụ riêng mới**, không thay model. Probe camera chỉ đọc tối đa 3 frame vào RAM rồi giải phóng, không preview/inference/lưu ảnh. Máy đã thấy Integrated Camera, DirectShow 640×480; kiểm tra hình ảnh/rút cắm vẫn cần người vận hành.

Runtime: SCRFD `det_500m.onnx` (320), ArcFace `w600k_mbf.onnx` (alignment112/512), buffalo_s/CPU; kiểm SHA chính xác trước khởi động. Không thay buffalo_l hoặc tải weights khác. Preview chỉ chạy detection sau consent; embedding chỉ dùng khi đánh giá offline.

## 2. Chuẩn bị người tham gia và kế hoạch trước khi thu

Chọn một thư mục private mới, **ngoài mọi Git worktree/repository**, được hạn chế truy cập và có chính sách lưu/xóa đã thống nhất. Không dùng thư mục tự đồng bộ hoặc upload ảnh ra ngoài. Dataset, consent, ảnh, kết quả chi tiết và embedding nếu có đều ngoài Git. Không đặt dữ liệu thu thật vào thư mục Temp của automated tests.

Người vận hành phải xác nhận quyền sử dụng ảnh, mục đích offline evaluation, phạm vi lưu giữ và quyền rút consent. Lưu chứng từ consent và bảng người thật ↔ mã ẩn danh riêng, không vào Git/báo cáo công khai. `operatorRef` và `consentRef` là UUID tham chiếu, không phải tên/email hay chứng từ consent đầy đủ. Xác nhận trên terminal chỉ là lời xác nhận của người vận hành, không thay thế consent thực tế.

```powershell
# Tự chọn đường dẫn private bền vững, ngoài Git; không dùng một đường dẫn đang chứa dữ liệu.
$study = Read-Host 'Thu muc private moi cho study'
$operatorRef = [guid]::NewGuid().ToString()
& $python -m face.evaluation.study init --study $study --dataset-version local-study-01 `
  --calibration-known 2 --calibration-unknown 1 --evaluation-known 2 --evaluation-unknown 1
& $python -m face.evaluation.study inspect --study $study
```

Kế hoạch tạo mã `p-...`, split và known/unknown từ đầu. Mặc định cần **6 người khác nhau**: mỗi split ≥2 known và ≥1 unknown. Đây chỉ là tối thiểu cấu trúc để kiểm tra 1:N/ambiguity, **không đủ để kết luận accuracy hoặc threshold production**. Chọn quy mô, điều kiện và tiêu chí chấp nhận trước khi thu. Nếu cần nhiều người hơn, đặt counts ngay lúc init; không đổi split sau khi xem điểm.

Một người chỉ một mã và một split; người vận hành chịu trách nhiệm không dùng mã khác cho cùng người. Tool kiểm trùng ảnh/hash/pixel và assignment, không thể chứng minh hai alias không phải cùng người. Unknown chỉ có probe, tuyệt đối không đưa vào gallery. Không dùng tên/email làm identity.

## 3. Preview và lưu từng ảnh do người vận hành điều khiển

Chọn subject từ kế hoạch, tạo consent reference riêng cho người đó và giữ bảng tham chiếu private. Với known, thu gallery trước; probe ở **lần gặp/phiên thực tế khác**, không cắt cùng video hoặc lấy frame liên tiếp chia hai tập. Với unknown chỉ thu probe. Không đổi mã/split giữa các phiên.

```powershell
$subject = Read-Host 'Ma p-... trong plan'
$consentRef = [guid]::NewGuid().ToString()
& $python -m face.evaluation.capture --study $study --subject $subject --role gallery `
  --operator-ref $operatorRef --consent-ref $consentRef --model-root $modelRoot --camera 0
# Lần gặp khác: dùng cùng subject/consentRef (nếu consent vẫn bao phủ), --role probe.
# Unknown: chỉ --role probe, không chạy gallery.
```

Cửa sổ ban đầu chỉ preview, không inference/lưu ảnh. Hình preview đảo ngang như soi gương; chữ không đảo. Ảnh được lưu theo ảnh camera gốc **không đảo**, provenance ghi rõ hai hướng.

1. Kiểm tra đúng người, một người trong khung, đã đồng ý; bấm **C** rồi quay về terminal nhập chính xác `CONSENT p-...`. Known probe còn phải nhập `INDEPENDENT` để xác nhận phiên khác gallery. Không pipe/auto-confirm: tool yêu cầu terminal tương tác.
2. Sau consent, khung ROI và hướng dẫn kích thước mặt, ánh sáng, độ nét, giữ ổn định dùng config prototype hiện có. Đây là quality gate, **không PAD/liveness**. Chỉ một mặt trong toàn frame; chưa READY thì không lưu.
3. Bấm **R** để chuẩn bị **một** ảnh; kiểm tra người/ROI rồi **Space** để lưu một ảnh READY. Sau mỗi lần lưu hoặc lỗi tool tự disarm; muốn ảnh tiếp theo phải R rồi Space lại. Không video, burst hoặc tự lưu khi đạt chất lượng.
4. **P** tạm dừng; **Q/Esc** hoặc đóng cửa sổ kết thúc và giải phóng camera. Mất camera tự pause/reset stability, reconnect không tự re-arm. Frame cũ quá 0,4 giây bị từ chối. Sau terminal consent luôn lấy frame mới.
5. Đóng session sau gallery. Chụp probe ở phiên khác, thay điều kiện/pose phù hợp protocol đã thống nhất; không cố loại ảnh khó chỉ vì điểm thấp. Cần người vận hành kiểm tra preview, mirror, rút/cắm, pause và kết thúc thực tế.

Mỗi session UUID ghi source camera/backend/model/config, thời điểm UTC, subject/split/role, consent references, hash ảnh và pixel; không lưu tên, JWT hoặc embedding trong capture. Không có lệnh upload hoặc gọi admission. Nếu ứng dụng dừng bất thường và còn lock/orphan, dừng thu và kiểm tra riêng; không tự xóa lock/file hoặc sửa manifest để ép seal. Tool không dọn dữ liệu người dùng tự động. Consent rút lại cần xử lý theo quy trình lưu giữ đã thống nhất trước khi đánh giá.

## 4. Khóa dữ liệu, calibration và evaluation

Khi tất cả planned known có gallery/probe khác session và unknown có probe:

```powershell
& $python -m face.evaluation.study seal --study $study
# Chỉ chạy các candidate đã lên kế hoạch; giá trị do người vận hành chọn cho calibration.
$candidateThreshold = [double](Read-Host 'Candidate cosine threshold (-1,1) cho calibration')
$candidateMargin = [double](Read-Host 'Candidate margin [0,1) cho calibration')
& $python -m face.evaluation.study calibrate --study $study --model-root $modelRoot `
  --threshold $candidateThreshold --margin $candidateMargin
# Xem các calibration-UUID.json PRIVATE, chọn bằng tiêu chí đã đặt; KHÔNG xem/tune evaluation.
$calibrationReport = Read-Host 'Ten calibration-UUID.json da chon trong study'
& $python -m face.evaluation.study freeze --study $study --calibration-report $calibrationReport
& $python -m face.evaluation.study evaluate --study $study --model-root $modelRoot
```

Seal đối chiếu consent/source/session, ảnh/hash/pixel/ID, file mồ côi, gallery/probe và identity split; tạo manifests + dataset lock bất biến. Calibration chỉ tính inference/điểm trên calibration; việc kiểm hash của evaluation là kiểm integrity, không tính điểm để chọn cấu hình. Freeze chỉ nhận tên báo cáo calibration trong study, không nhận threshold mới. Sau freeze không thêm candidate hoặc chỉnh ảnh/split. Evaluation không có tham số override và chỉ ghi một lần. Source/preprocessing/model/dependencies và dataset phải khớp dấu vân tay; thay đổi bị từ chối, không âm thầm sửa.

Kết quả private ghi model/preprocessing/threshold/margin/gallery size/dataset version, genuine/impostor **identity-max cosine** (không phải toàn bộ image pairs), score-threshold FA/FR, known wrong-identification/rejection, FNIR/FPIR/rank1, unknown rejection, ambiguity, failure-to-acquire và median/p95 latency inference/identification. Không lấy pair accuracy thay kết quả kiosk. Không có mẫu hoặc không có gallery dùng được thì báo thiếu, không tự điền số. Hash/lock chống thay đổi vô ý; không phải audit chống chủ dữ liệu cố ý sửa toàn bộ history. Không tạo study/split mới chỉ để tăng điểm sau evaluation.

Legacy `face.service_v2.evaluate --phase evaluation` bị chặn để tránh nhập lại threshold trực tiếp; dùng workflow trên. Báo cáo này không mở liveness/admission gate. Chỉ chia sẻ aggregate đã review, không commit private manifests/scores chi tiết/ảnh hoặc consent.

## 5. Chạy tests không cần người thật

```powershell
& $python -m pytest face/evaluation/tests face/service_v2/tests face/integration/tests `
  --rootdir=. -p no:cacheprovider -q --junitxml="$private/regression.xml"
```

`$private` là thư mục report riêng ngoài Git. Tests dùng ảnh checkerboard/noise không phải người, fake engine chỉ trong unit tests. Pinned camera/selector/state/auth tests cần export đúng ref theo evidence và chạy riêng ở private directory với `PYTHONPATH` worktree (không gộp đường dẫn C: và D: làm pytest scan Windows root). Manual webcam test giữ skip; unit GUI mocks không chứng minh GUI/camera/accuracy thật.

## Việc cần người vận hành thực hiện

Chạy preview trực tiếp và kiểm camera/mirror/rút cắm; chuẩn bị người tham gia được phép, consent/retention và phân nhóm trước; tự bấm thu từng ảnh ở các phiên độc lập; seal rồi chọn candidate từ calibration và đánh giá một lần. Chưa có approved dataset nên chưa có số accuracy/threshold production. Không cần khởi động Backend/DB để thu/evaluate offline; không đổi cấu hình default hoặc admission. Sau chạy thoát Q, giữ dữ liệu private đúng thời hạn đã thỏa thuận, không broad delete.
