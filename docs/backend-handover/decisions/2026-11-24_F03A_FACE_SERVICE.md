# F-03A — Face Service transport và evaluation (24/11/2026)

Nguồn: yêu cầu F03A của người dùng; [F01 survey](../evidence/F01_FACE_SOURCE_SURVEY.md), [F02](2026-11-24_F02_FACE_ENROLLMENT.md). Đây là lựa chọn kỹ thuật trong rehearsal, **không duyệt threshold production/PAD hoặc thu biometric mới**.

## Source/model và trust

- Import riêng các dependency cần dùng từ Face pin `fcabeba765d6e597cbc5fbed76fafc08f9604e03`, bytes nguyên bản theo provenance trong evidence; không merge nhánh Face, không đè checkout/model/cache gốc. Kiosk app mới mà README cũ nhắc vẫn chưa xác định ref; không giả đã tích hợp camera.
- Giữ InsightFace `buffalo_s`: SCRFD `det_500m.onnx`, ArcFace/MobileFaceNet512 `w600k_mbf.onnx`, CPU, detection320 và alignment112 của source hiện có. Cache `buffalo_l` sẵn trên máy **không được dùng thay**. Tải đúng [official v0.7 asset](https://github.com/deepinsight/insightface/releases/tag/v0.7) vào private Temp, ghi SHA256; API release không có publisher digest, không gọi local hash là chữ ký nhà phát hành. [Upstream model usage/license](https://github.com/deepinsight/insightface/tree/master/python-package) cần giải quyết trước gym deployment.
- Production CLI chỉ nạp model thật, preflight artifact/dependency, không fallback engine synthetic và không tự tải cache. Test host riêng, guard private Temp và `F03A_SYNTHETIC_PROTOCOL_ONLY`, ảnh uniform/one-hot không phải khuôn mặt người.
- Control, capture và signing key chỉ private server; không Frontend/CORS, bind127.0.0.1, no redirects, HTTP timeout hữu hạn/no replay. Model mode `MODEL_INFERENCE_UNCALIBRATED`; test mode `SYNTHETIC_PROTOCOL`.

## Lifecycle ngoài PostgreSQL

[Private service contract/OpenAPI](../../../face/service_v2/openapi.json), [store](../../../face/service_v2/store.py), [adapter](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/enrollment/RemoteEnrollmentAdapter.java).

1. Prepare ràng buộc operation/member/profile/reference/predecessor bất biến; generation tăng theo Member trong SQLite. Reference do Backend mint `f02:<profile UUID>`, không alias tên/email/users.id. Same operation khác payload409.
2. Trusted process gửi5–15ảnh, cần >=3 usable embeddings. Staging chưa nằm trong gallery nhận diện. Gallery tái dùng normalize/search/register source pin. Reservation giữa ACTIVE/STAGED dưới SQLite write lock chặn duplicate của Member khác trước DB commit; duplicate check hai chiều để tránh directional mean/vector race. Exclude đúng Member (bao gồm predecessor của chính mình), không nhầm re-enrollment là người khác.
3. Backend giữ Member→operation→profile như F02. External prepare ngoài transaction; chưa có samples trả503 `ERR_FACE_SAMPLES_REQUIRED`, operation vẫn PENDING, old profile không đổi. DB activation/audit transaction commit trước external finalize. SQLite transaction chỉ bao phủ metadata/vector ciphertext, **không phải distributed transaction PostgreSQL+filesystem**.
4. Complete thành công200 chỉ sau finalize ACK. Timeout trước commit giữ PENDING; timeout sau commit có thể DB ACTIVE/service STAGED hoặc ACTIVE. Không coi GET status DB ACTIVE là chứng minh publication đã xong; gọi Complete **cùng operation** để reconcile, không start enrollment mới. ACTIVE retry kiểm binding/generation và publish idempotent, không thêm profile/audit.
5. Revoke DB chặn Core ngay, outbox abort theo managed owner/ref; abort tombstone bền kể cả chưa prepare. Finalize sau tombstone409, không resurrect. Service finalize thay predecessor atomically, chỉ ACTIVE được recognition; cleanup predecessor không đụng Member khác. Failed sample/duplicate stage giữ profile cũ. Publication chưa rõ là recovery pending, không khẳng định rollback external hoặc old DB profile vẫn ACTIVE sau commit.
6. Không tự adopt legacy alias/gallery thiếu mapping. Legacy predecessor không có managed UUID binding phải reconcile có chứng cứ riêng; không suy identity từ tên/email hoặc xóa theo prefix.

SQLite encrypted embedding payload bằng Fernet; atomic transaction/full synchronous, immutable operation/sample digest, model/key fingerprint, không lưu raw ảnh. Abort/replacement xóa ciphertext mẫu của reference đó; operation/tombstone/capture proof còn private để chống replay. Chưa có retention/key rotation/production recovery policy được phê duyệt.

## Attestation và admission gate

Capture chỉ nhận request/capture UUID + frames từ capture principal tin cậy; không nhận claimed member/score. Service ký exact base64url payload bằng HMAC-SHA256, ràng buộc request/capture/profile/reference/generation/model/provenance; issuedAt/expiresAt UTC epoch, TTL10s từ **một lần đọc Clock**, replay không kéo dài TTL. Proof cached có thể là kết quả cũ; consumer phải kiểm current mapping/state/generation và hạn.

Backend verify signature, request/capture, integer time/generation, TTL/binding/provenance; đọc ACTIVE FacialProfile↔enrollment↔members.id và service generation. **NOT_PERFORMED không phải PASSED**. Chưa có PAD/threshold được duyệt nên remote path không trả identity có quyền admission, kể cả proof hợp lệ. F01 simulated fixture vẫn là test riêng có guard. Không thay cooldown5s/one-in-flight/stale handling, không gọi đó là camera E2E.

V12/V13 chỉ cho `SIMULATED_TEST`; không ghi inference thật vào mode này. Vì thế adapter Backend hiện chỉ publish profile từ test-host `SYNTHETIC_PROTOCOL`; model thật bị503 `ERR_FACE_REAL_ADMISSION_NOT_ENABLED`, không tạo mapping thật hoặc Attendance. Service thật tự chạy với model được, nhưng **Backend real enrollment/admission chưa mở**. Không thêm migration để lách gate; default release properties giữ nguyên.

## Evaluation và phần chưa đủ

[Harness](../../../face/service_v2/evaluate.py) yêu cầu manifest được phép sử dụng, version/SHA256, pseudonymous subject cho cả known/unknown. Calibration/evaluation tách identity và bytes/hash; gallery/probe khác file/hash trong mỗi manifest. Threshold/margin phải nhập rõ, không tự công bố production threshold. Báo probe-to-gallery identity-max genuine/impostor scores, score threshold FA/FR (không phải all-pair accuracy), 1:N correct/wrong/rejected known, FNIR, unknown FPIR/rejection, ambiguity/rank1, inference và 1:N latency, model/preprocessing/gallery size/dataset versions. Synthetic unit kết quả chỉ kiểm phép tính.

Không có authorized biometric dataset được cung cấp nên không chạy calibration/accuracy. Cần dataset có quyền dùng, identity/split/session labels, enrollment/probe và unknown cohorts, camera/illumination representative; PAD cần attack/replay/print/display và bona-fide dữ liệu được phép. Chưa chọn PAD model/threshold, không coi camera quality/ROI là liveness. Không thu người thật/upload trong task.

Release vẫn bị chặn bởi shared migration inventory/V7/backfill và đồng bộ V8–V13; F03A không thay canonical/applied SQL, không DB chung. [Evidence](../evidence/F03A_FACE_SERVICE.md).
