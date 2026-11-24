# F-03B — Quyết định kỹ thuật camera/evaluation, 24/11/2026

Nguồn: yêu cầu F03B từ người dùng, [F03A contract](2026-11-24_F03A_FACE_SERVICE.md), [F01 source survey](../evidence/F01_FACE_SOURCE_SURVEY.md). Base `70ca11ce4eee068b1b25147e829b0d804e105a53`, Face pin `fcabeba765d6e597cbc5fbed76fafc08f9604e03`.

## Phạm vi và nguồn

Không chọn model/threshold mới. Import riêng camera resource lifecycle và quality measurement từ pin Face; tái sử dụng selector/stability/config, SCRFD buffalo_s/ArcFace và 1:N evaluator F03A. Không overwrite Face checkout/untracked/model/cache. Capture là công cụ offline, không enrollment F02, trusted capture transport hoặc kiosk admission. Kiosk một request in-flight/cooldown5s và Backend rolling30min không thay đổi; công cụ này chỉ lưu từng still thủ công, không gửi request.

## Consent, source và split

Mặc định preview/transient RAM, không inference trước consent hoặc ghi ảnh. Terminal tương tác, xác nhận consent chủ động; R + Space cho từng ảnh, tự disarm, pause khi mất camera, chống frame cũ. Preview mirror, ảnh raw không mirror. Chỉ một mặt đạt ROI/quality/stability hiện có; quality không phải liveness. Manifest local có subject ẩn danh/session UUID/operator+consent UUID/source/time/hashes; người vận hành giữ chứng từ và mapping cá nhân riêng ngoài Git, không thu người thật tự động.

Plan tạo trước, một subject/một split, known gallery+probe khác session, unknown probe-only. Calibration/evaluation disjoint identities và ảnh/hash/pixels. Known probe cần operator xác nhận phiên gặp khác gallery; source alone không tự chứng minh được điều đó. Mỗi split tối thiểu2known+1unknown là cấu trúc, không chứng minh đủ mẫu thống kê. Không dùng split mới/chọn lọc ảnh để tăng điểm. Công cụ không nhận diện cùng người đăng ký hai alias hoặc mọi near-duplicate; đó là trách nhiệm protocol/operator.

## Khóa dữ liệu và threshold

Seal tạo manifests/dataset-lock có plan/session/image hashes, từ chối orphan/duplicate/missing data; không sửa split để chạy qua. Calibration chỉ lấy điểm từ calibration. Freeze chọn một báo cáo calibration đã có, khóa threshold/margin/model/source/preprocessing/dependencies; evaluation không nhận threshold mới, không overwrite hoặc tự tune. Legacy CLI evaluation trực tiếp bị chặn; các hàm metrics F03A giữ nguyên. Local locks/hash chống lỗi vô ý, không phải chống người sở hữu filesystem cố ý sửa mọi chứng cứ.

Dữ liệu và report chi tiết luôn ngoài mọi Git worktree; create-only/atomic replacement có cleanup đúng file tự tạo, không broad delete. Không xóa/recover stale lock tự động. Người vận hành thống nhất retention/rút consent trước khi thu. Không thêm dịch vụ upload hoặc dữ liệu biometric vào repository.

## Gates và giới hạn

`liveness=NOT_PERFORMED`, `admissionEnabled=false`, `productionThresholdApproved=false`. Không thêm PAD, không đổi schema/default/backend admission gates. Camera IOprobe không chứng minh visual preview/unplug/camera recognition. Generated-input inference/unit metrics không phải accuracy. Dataset được phép, camera manual, PAD/attack evaluation và tiêu chí threshold production vẫn cần cung cấp/kiểm chứng. [Hướng dẫn từng bước](../25_FACE_CAMERA_EVALUATION_QUICKSTART.md), [evidence](../evidence/F03B_CAMERA_EVALUATION.md).
