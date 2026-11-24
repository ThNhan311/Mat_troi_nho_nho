# F-01 — Core check-in và ranh giới Face

Base renewal4af8bb8, branch feature/face-checkin-core. Nguồn đã đọc: Topic11 UC06/07, Listing5.4, AC-CHK01..04; V3; Face spec0.3/API_CONTRACT tại origin/feature/face-1n-identification **fcabeba**; kiosk source origin/frontend **0307242**. Không sửa Face untracked ở checkout gốc.

## Source hiện có và giới hạn

Face branch đã có detection/qualityROI/state machine, embedding InsightFace buffalo_s, matcher cosine/threshold0.5/margin0.05, encrypted gallery, enrollment và FastAPI health/identify/enroll/delete. Đây là mô tả source, **không phải chọn/duyệt threshold hoặc model mới**. README ghi threshold chưa hiệu chỉnh, một người từng demo; liveness NOT_PERFORMED. F01 không kiểm chứng lại camera/recognition/liveness hoặc thu dữ liệu sinh trắc học. Checkout gốc chỉ còn untracked caches/model/venv, source thật được đọc từ ref đã pin; không ghi đè/move các file đó.

README Face nói kiosk đã nối service nhưng source kiosk tìm thấy ở origin/frontend0307242 vẫn mock trả tên cố định; không coi README là bằng chứng đã tích hợp. Không import toàn nhánh Face/Frontend hoặc thay prototype. Adapter mới là addon hẹp, được kiểm hợp đồng với state machine/SingleFlightWorker của source Face đã pin trong bản export private chỉ đọc.

## Contract F01 (lựa chọn triển khai)

POST `/api/v1/check-ins/face` trả200 theo Topic11. Chỉ **registered kiosk/service credential** riêng, không chấp nhận JWT Member/Admin/PT làm identity attestation. Default gate off503; test adapter chỉ bật trên profile checkin guard, loopback và private fixture file. JSON rehearsal chỉ requestId UUID và captureRef UUID opaque; **không memberId/profileId/status/score từ client**. Server adapter map captureRef sang synthetic facialProfile UUID; Core tự tìm members.id qua V3. Response luôn simulatedIdentity=true/verificationMode=SIMULATED_TEST. Không nhận ảnh hoặc embedding trong task này. Multipart faceImage của Topic11 để dành adapter thật sau ADR03/04; rehearsal JSON không phải tuyên bố contract camera production đã hoàn thành.

Response: requestId, recognized, accessAllowed, attendanceCreated, attendanceId nullable, memberId nullable, checkedAt UTC, checkedInAt nullable, reason, replayed, simulatedIdentity, verificationMode. No-match/unknown/profile inactive/account inactive/membership inactive/unpaid coverage đều không insert Attendance. recognized không đồng nghĩa được vào: phải đọc accessAllowed. Duplicate window trảrecognized=true, accessAllowed=true, attendanceCreated=false, reason=DUPLICATE_WINDOW khi điều kiện hiện tại còn hợp lệ.

Cửa sổ rolling dựa trên lượt Attendance gần nhất: now < last+30phút là duplicate; **đúng30phút** được tạo lượt mới. Cooldown5giây của camera là quy tắc khác. Request ID global; fingerprint gồm authenticated kioskId và captureRef, cùng ID khác payload/kiosk409 ERR_CHECKIN_REQUEST_REUSED. Replay không insert hoặc đổi metadata ledger; vẫn kiểm account/profile/membership/paid coverage hiện tại, response checkedAt mới và attendanceCreated=false. Ledger giữ quyết định gốc để audit; replay không tái chạy nhận diện. Muốn scan mới phải dùng request ID mới sau quy tắc kiosk.

GET `/api/v1/attendance/me?from=<offsetISO>&to=<offsetISO>` trảarray theo convention đọc lịch; from inclusive/to exclusive, from<to. Chỉ MEMBER ACTIVE, owner từ principal/profile UUID. Fields id,checkedInAt UTC,source,kioskId,verificationMode. V3 source chỉ FACE; ledger phân biệt SIMULATED_TEST, rows cũ thiếu provenance UNVERIFIED_LEGACY; không gọi test rows là nhận diện thật.

## Transaction/schema/khóa

V3 đủ attendance nhưng dedupe_key không lưu fingerprint/outcome cho mọi request nên cần **V12 additive ledger** riêng rehearsal. Không sửa V1–V11/không áp V7 destructive. V12 giữ toàn bộ attendance/facial profiles/payment periods/receipt/snapshots/activation states. Release vẫn cần shared inventory và đồng bộ thứ tự với Duy; không out-of-order/history edits/clean/repair.

Mọi Core write dùng transaction READ_COMMITTED: request advisory lock kỹ thuật theo UUID → Member NO KEY UPDATE → Membership FOR UPDATE → FacialProfile FOR SHARE → re-read account/profile/coverage → Clock sau chờ → dedupe/insertAttendance+ledger nguyên tử. Các writer R03/R04/M03/renewal không lấy request lock, không có đường ngược về request; Member vẫn đứng trước business rows. Request PK/unique dedupe/creation ledger là lớp cuối. Hai request khác ID cùng Member serialize trên Member, không dùng bucket30phút sai biên. Replay cùng ID lấy cùng technical lock trước rồi kiểm Member, không dùng entity stale. Không khóa User theo thứ tự ngược activation.

Membership phải ACTIVE, startDate<=todayVN<=expiryDate inclusive, paid coverage bao phủ hôm nay qua period service renewal; không chọn phần tử đầu tùy ý hoặc tự cộng quyền. Facial profile phải ACTIVE. History dùng repeatable-read/readOnly. Không cập nhật User/Membership/payment/Booking.

## Chưa chốt/ngoài F01

Cần quyết định/kiểm chứng cho adapter thật: gallery ID (ví dụ M001) mapping sang facial_profiles/members UUID, enrollment consent/revoke atomic, model/license/threshold/FAR-FRR có bằng chứng, liveness/PAD, capture transport/deployment/TLS và credentials kiosk production, retention. Không âm thầm cho NOT_PERFORMED thành liveness passed hoặc bật service default. Core simulated E2E không phải Face ID E2E.

Replay của request vốn bị từ chối không biến thành admission mới khi điều kiện tốt trở lại: REQUEST_PREVIOUSLY_DENIED, cần thao tác scan/request mới. Replay của admission cũ vẫn có thể bị từ chối nếu điều kiện hiện tại mất hiệu lực. Clock F01 được truncate microsecond để DTO/PG timestamp khớp precision, vẫn giữ đúng biên30phút/ngày.
