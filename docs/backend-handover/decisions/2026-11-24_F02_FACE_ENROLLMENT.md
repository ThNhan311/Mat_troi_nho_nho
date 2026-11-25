# F02 — Enrollment lifecycle / mapping

Base F01 c3eb411, branch feature/face-enrollment. User giao Admin ACTIVE tại gym, xác minh Member/consent, một FacialProfile ACTIVE, re-enroll failure giữ mẫu cũ, revoke vô hiệu hóa nhận diện cũ. Đây không phải quyết định chấp nhận model/threshold/liveness. [Source F01](../evidence/F01_FACE_SOURCE_SURVEY.md), [evidence](../evidence/F02_FACE_ENROLLMENT.md), [quickstart](../23_FACE_ENROLLMENT_QUICKSTART.md).

## Source đã xác minh và ranh giới adapter

Fetch origin giữ Face **fcabeba765d6e597cbc5fbed76fafc08f9604e03**, database **558fb03fd5927ca9e04d17b54fd46e429fe62bb5**. Đọc lại face/service/api.py, prototype/enroll.py/gallery.py từ ref này. Không import/overwrite prototype hoặc Face untracked. Service thật đã có multipart POST /v1/enroll, admin token, 5–15 frames />=3 vectors, register duplicate check, Fernet/atomic file replace và DELETE /v1/members/{alias}. Liveness NOT_PERFORMED. Không chạy chúng với người thật.

Contract thật chưa có operation ID/idempotency, stage/status/finalize, generation và compensate restore. enroll thay alias ngay; dùng alias profile mới sẽ đụng duplicate detector với chính mẫu cũ, dùng alias Member cố định sẽ overwrite trước DB commit. Vì vậy không giả transaction bao trùm gallery, không tự sửa toàn service. F02 hoàn thành Core lifecycle với **EnrollmentTestAdapter** journal external riêng, mode SIMULATED_TEST, profile face-enrollment-rehearsal/default off. Không có endpoint chọn outcome hoặc tự nhận template từ client; test scenario config private server-side, không ảnh/vector/model/camera.

## Contract và danh tính

[OpenAPI](../api/openapi.yaml). Admin paths `/api/v1/admin/members/{member}/face-enrollments`:

- GET list trả memberId/profiles/enrollments; GET /{operation} đối chiếu trạng thái. UUID member là members.id, khác users.id.
- POST start cần Idempotency-Key UUID và **chỉ** consentAccepted=true, memberVerified=true, atGym=true, consentVersion nonblank<=64. HTTP201 PENDING; re-enroll dùng cùng endpoint. Boolean không coercion; unknown/duplicate fields bị400. Consent timestamp/actor do server; row PENDING chứng nhận ba attestation true. UI dùng face-consent-v1; đây là version marker test, không chứng minh đã có consent người thật hoặc approved production notice.
- POST /{operation}/complete body rỗng: server adapter xác nhận đúng operation/member/profile/reference và READY rồi mới ACTIVE. HTTP200 phải đọc status, FAILED không là thành công enrollment. Operation ID là idempotency, lặp không ghi profile/audit lần hai.
- POST /{operation}/revoke hủy PENDING, trả REVOKED, không đụng mẫu cũ. ACTIVE phải dùng profile revoke; sai transition409 ERR_FACE_ENROLLMENT_NOT_PENDING. Lặp REVOKED giữ metadata.
- POST /profiles/{profile}/revoke cần Idempotency-Key UUID/body rỗng. Thu hồi DB ngay, không rollback revoke chỉ vì external deletion chưa xong. Cùng key khác Member/profile409; profile không thuộc Member404. Repeated revoke không thay profile revokedAt hoặc ghi audit lần hai; key khác có thể tạo record đối chiếu với actor/thời điểm xác nhận của request mới, nhưng không tái chuyển trạng thái; profile revokedAt và audit thu hồi gốc giữ nguyên.

Chỉ ADMIN ACTIVE, actor principal/recheck sau khóa; role sai403, thiếu/invalid JWT401, disabled account JWT401 theo conventions. Sai Member/operation/profile404. Default ADMIN503 ERR_FACE_ENROLLMENT_UNAVAILABLE. No-store. Không trả template_ref/gallery alias/captureRef/token/ảnh/vector. Start same key/payload trả cùng operation và **trạng thái hiện tại**, không frozen payment snapshot; khác payload409 ERR_IDEMPOTENCY_KEY_REUSED. Một PENDING mỗi Member; key mới khi còn PENDING409 ERR_FACE_ENROLLMENT_PENDING. Start không yêu cầu Membership hoặc tự kích hoạt User.

Mapping do server mint: operation UUID → proposed profile UUID → `f02:<profile UUID>` → FacialProfile(member_id) → members.id. Activated_profile composite owner FK, template_ref unique trong operations; V3 giữ unique ACTIVE/member. Recognition test trả opaque captureRef private → server journal attestation reference → join managed enrollment/FacialProfile; client không thể gửi template/member để được match. Core vẫn recheck profile/account/paid Membership. Captures/requests cũ trỏ profile revoked không được cấp quyền, kể cả gallery removal lỗi.

## Transaction, lock và external lifecycle

READ_COMMITTED writes: technical start/revoke request advisory lock → Member NO KEY UPDATE → operation → FacialProfile. Không giữ khóa nghiệp vụ trong external I/O; không khóa User ngược activation. F01 Member→Membership→profile tương thích vì Member đứng trước, lifecycle không lấy Membership sau profile. Admin/Clock đọc lại sau locks. Read API REPEATABLE_READ/readOnly.

1. Commit PENDING + consent/actor/audit trước prepare. Adapter stage idempotent theo operation, immutable binding trong journal private. Không ACTIVE trước READY.
2. Sau external call, transaction mới khóa lại/re-read; kiểm old profile vẫn đúng, binding và READY. Revoke old + insert new + operation ACTIVE + audit + old-template cleanup outbox nguyên tử. FAILED giữ old ACTIVE, ghi failure và compensate candidate qua outbox.
3. DB rollback sau external READY: old vẫn ACTIVE, operation PENDING, stage còn có tên/reference để recovery; GET đối chiếu rồi explicit complete **cùng operation**. Không tuyên bố external stage đã rollback hoặc retry tự động. Outbox removal ngoài transaction, chỉ DONE sau adapter ACK; crash trước DB ACK có thể remove lại an toàn.
4. Revoke vô hiệu DB ngay và chặn pending re-enroll dựa trên profile cũ. Durable removal tombstone test chống stage tới muộn hồi sinh; external failure giữ PENDING cleanup, retry revoke/complete explicit sẽ drain. Legacy chưa có managed binding là MANUAL_REQUIRED, không xóa dựa vào prefix/alias client. Legacy reference trùng managed Member khác không được xóa mẫu của họ; cần đối soát mapping thủ công, cleanup global reference có thể còn manual.

Không đổi User/Member/Membership/payment/receipt/Booking. Audit chỉ FACIAL_PROFILE. Đây là saga có pending/finalize/outbox/reconcile, **không distributed ACID**. Chưa background delivery/retention worker hoặc operator orphan dashboard; pending operation phải được reconcile/revoke rõ ràng.

## Schema và release gate

V13 additive rehearsal riêng: face_enrollments (consent, actors, idempotency/binding/state), face_revocations (key/actor/time), face_gallery_cleanup (durable removal state), owner index/FK FacialProfile. Không đổi V3 status hoặc migration đã áp. Frozen candidate1–6,8–13/12scripts, gap7; không V7 destructive/out-of-order/history edits/clean/repair/renumber. Default gates và DB chung giữ nguyên. Test empty/history upgrade bảo toàn rows, periods/M03 snapshots/activation state; shared inventory chưa biết nên **releaseReady=false**.

## F03 cần bổ sung

Service contract server-to-server: authenticated operation/proposed profile generation và logical Member UUID; prepare/status/finalize/abort/remove idempotent; durable READY/ACK và reference ownership; exclude đúng predecessor khi kiểm duplicate cùng người, không cho duplicate identity sang Member khác; crash recovery và revoke generation. Thêm capture attestation không tin browser, TLS/credential deployment, calibration/model/license/FAR-FRR và phương án liveness/PAD. Source kiosk mới thực sự nối service chưa xác định; không lấy README làm bằng chứng. Consent tại gym đã là yêu cầu, còn production notice/version/retention/revoke deletion audit phải được hoàn thiện trước biometric thật. F02 không thu hoặc kiểm chứng identity/liveness người thật.
