# Quyết định FitCenter

Nguồn chuẩn: yêu cầu người dùng của phiên, Topic11 và tài liệu quyết định chi tiết. Các bảng đề xuất trong [khảo sát](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md) chưa tự trở thành quyết định.

## Đã chốt

- Booking auto-confirm,90phút; D01–D07/PT cancel/service eligibility: [quyết định Booking](backend-handover/decisions/2026-11-20_BOOKING_DECISIONS.md). Eligibility chỉ snapshot, không start marker; completion giữ R04.
- M-01 Admin create plan ACTIVE, ngày/price0/tên không unique; [contract](backend-handover/decisions/2026-11-22_M01_PLAN_CREATE.md). M-01 đã kiểm chứng, đóng tại commit6fbf9fc; không làm lại trong task account.
- Admin tạo account chưa kích hoạt. User+Member/PT profile nguyên tử; account creation không tạo/activate membership.
- Chỉ PT first activation được giao: email → OTP email5phút → verify thành công → đặt mật khẩu → ACTIVE → login email/password. Không suy ra MEMBER activation.
- OTP một lần, không lưu/log rõ, kiểm expiry/attempt/resend; verify/password transition nguyên tử, không cấp JWT thường khi chưa ACTIVE.
- Chỉ mail test, không người thật; không áp migration chưa thống nhất. Yêu cầu mới cho phép commit/push phần đã review lên nhánh chức năng riêng, chưa merge.

## Lựa chọn kỹ thuật trong task hiện tại

- Dùng status DISABLED sẵn có cho account chưa kích hoạt để không sửa V1/enum. Audit event ACCOUNT_CREATED_PENDING_ACTIVATION là dấu nguồn Admin tạo mới; không hiểu mọi tài khoản DISABLED cũ là được tự kích hoạt. Membership status độc lập.
- Hai endpoint Admin riêng /admin/members và /admin/personal-trainers, role server; response userId/profileId khác nhau. Password placeholder BCrypt ngẫu nhiên không bàn giao, không thể login trước ACTIVE.
- OTP6chữ số SecureRandom, BCrypt digest,5attempt/challenge; resend tối thiểu60giây,tối đa5lần/giờ/account. Grant đặt mật khẩu ngẫu nhiên32byte, chỉ lưuSHA256,TTL5phút,một lần; không phải JWT. Các giới hạn chống lạm dụng là lựa chọn kỹ thuật, không sửa Booking/Membership policy.
- Password8ký tự trở lên, tối đa72byteUTF-8 theo BCrypt, không silent truncation/composition rule mới.
- Khóa User → activation row; Clock lấy sau chờ khóa. Mọi bước kiểm lại rolePT/status/marker; completed không tái kích hoạt.

## Snapshot trước quyền rehearsal (được cập nhật ở phần quyền mới bên dưới)

- Canonical V1–V6 không có bảng OTP/grant/counter. Chuẩn bị SQL candidate ở docs/backend-handover/proposals, không tên V7/V8, không tự apply hoặc sửa guards. V7 của Duy558fb03 là membership periods và còn rủi ro DROP chưa backfill: [review](backend-handover/decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md).
- PT activation mặc định tắt trước khi schema/version được thống nhất. Code/unit/mail test không thay bằng chứng HTTP/PostgreSQL activation thật.
- MEMBER activation, production mail delivery, password reset, account edit/status/delete, membership activation/renewal/payment chưa thuộc task.

Chi tiết API/error/lock, giới hạn SMTP và checklist thống nhất schema: [Account/PT activation](backend-handover/decisions/2026-11-22_ACCOUNT_PT_ACTIVATION.md). SQL candidate không phải migration được phép apply.

## Quyền mới và kết quả rehearsal PT activation — 22/11/2026

Người dùng cho phép tạo/apply schema trên PostgreSQL test riêng và commit/push nhánh chức năng, không phải DB chung/production. Hạn chế chờ Duy ở các snapshot cũ được thay trong phạm vi test này. V8 ở location riêng; default profile vẫn false/503, không áp V7/out-of-order/repair. Đã đạt HTTP/PostgreSQL/SMTP/UI activation thực; cần đồng bộ Duy trước merge/release, không còn chặn test độc lập. [Quyết định chi tiết](backend-handover/decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md).

## M-04 — Member Membership read —23/11/2026

Người dùng giao nối GET `/api/v1/memberships/me` vào MembershipPage/navigation Member gốc. Array không có ordering/current-selection contract; hiển thị danh sách tất cả rows, không suy phần tử đầu là current/next. Dùng id/planId/planName/startDate/endDate/status server; DATE là lịch Việt Nam, trạng thái hiệu lực đã do Backend tính. Không dựng price/paidAt/payment history hoặc period model. Gia hạn/thanh toán Chưa khả dụng; MEMBER ACTIVE chỉ seed test, chưa triển khai MEMBER activation. Không API/schema/Booking/default activation thay đổi. [Evidence](backend-handover/evidence/M04_MEMBER_MEMBERSHIP.md), [chạy lại](backend-handover/17_MEMBER_MEMBERSHIP_READ_QUICKSTART.md).

## M-03 chuẩn bị — chưa chốt nghiệp vụ —23/11/2026

Người dùng giao chuẩn bị Admin ghi nhận thanh toán quầy và kích hoạt Membership lần đầu cho Member đã tồn tại, tách khỏi tạo User/profile. Giữ Member-first locking và Booking; không áp V7 DROP periods chưa backfill, không dùng history rehearsal1–6,8 làm release. **Ngày/giá/chứng từ/MEMBER activation còn chờ xác nhận**, không tự chuyển User DISABLED→ACTIVE. [Contract/schema/test plan đề xuất](backend-handover/proposals/2026-11-23_M03_COUNTER_ACTIVATION.md), [DDL candidate chưa áp](backend-handover/proposals/M03_COUNTER_ACTIVATION_SCHEMA_CANDIDATE.sql). POST/reconcile GET, Idempotency-Key, receipt uniqueness, counter SUCCESS so với V7 ACTIVATION không tx, slotV9 đều là đề xuất, chưa triển khai hoặc phê duyệt.

## M-03 đã phê duyệt và triển khai —23/11/2026

Quyết định mới thay phần đề xuất chưa chốt ở trên: Clock VN/date inclusive, giá ACTIVE server (giá0), chứng từ global/idempotency, initial chưa có lịch sử, không kích hoạt User. [Contract/khóa/chuẩn hóa/schema và giới hạn](backend-handover/decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md). MEMBER email OTP/password được đồng ý là task riêng, chưa triển khai trong M-03. V9 location rehearsal riêng/default-off; không áp V7 hoặc đưa history1–6,9 thành release.

## MEMBER account activation — đã giao triển khai23/11/2026

Quyền mới thay giới hạn PT-only trong snapshot trước: Member Admin tạo email→OTP5phút→password→ACTIVE, không cần Membership và không tác động Membership/payment. Core dùng chung nhưng role/store/challenge/grant riêng; V10 chỉ rehearsal guard tích hợp15441, default-off. [Quyết định/contract/schema/khóa](backend-handover/decisions/2026-11-23_MEMBER_ACCOUNT_ACTIVATION.md). Không đồng nghĩa phát hành production hoặc gateway.

## I-01 — ứng viên tích hợp23/11/2026

Không thêm quy tắc nghiệp vụ hoặc sửa migration đã công bố. Frozen1–6,8–10 chỉ rehearsal; V7 quarantine, shared inventory chưa có nên không kết luận release-ready hoặc V7 chưa áp nơi khác. Cùng backend/profile/DB/mail cho Account→Membership→Booking, chỉ seed Admin cho E2E. Không clean/repair/out-of-order/renumber để vượt gap7. [Inventory/quyết định kỹ thuật/release gates](backend-handover/decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md), [evidence](backend-handover/evidence/I01_CORE_INTEGRATION.md).

## M-05/M-06 — quyết định đã phê duyệt23/11/2026

Gia hạn giữ UUID, ngày VN inclusive, early nối kỳ trả tiền/expired bắt đầu hôm nay, snapshot tại initiation, gói khác chỉ kỳ mới, SUSPENDED/CANCELLED cần đối soát nếu đã thu tiền. Hai SUCCESS độc lập append tuần tự, idempotency/event replay không nhân đôi. Simulator default-off, ADMIN ACTIVE/test-only. Các giới hạn “renewal chưa triển khai” ở snapshot trước được thay trong profile rehearsal này; chưa gateway/refund/production rollout. [Contract/quyết định/khóa/schema/release gates](backend-handover/decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md).

## F-01 — Core check-in đã giao24/11/2026

User cho phép Core check-in + adapter test riêng nếu Face/liveness chưa đủ bằng chứng. V3 Attendance, rolling30phút và eligibility hiện tại; request ID chống replay/khác payload; owner history qua principal. F01 không chọn model/threshold mới hoặc thu biometric thật. [Contract/khóa/V12/giới hạn](backend-handover/decisions/2026-11-24_F01_CHECKIN_CORE.md), [source Face thực tế](backend-handover/evidence/F01_FACE_SOURCE_SURVEY.md). Các giới hạn “không Face” trong snapshot cũ được thay chỉ trong phạm vi Core/test addon này; chưa production Face rollout.

## F02 — enrollment lifecycle đã giao24/11/2026

Admin tại gym xác minh Member/consent; server-owned mapping, READY mới ACTIVE, re-enroll failure giữ old, revoke chặn Core ngay. [Contract/saga/V13/giới hạn](backend-handover/decisions/2026-11-24_F02_FACE_ENROLLMENT.md). Chỉ simulated adapter guard/default-off khi service thật chưa đủ staging/version/idempotency; không duyệt model/threshold/liveness hoặc thu biometric thật.

## F03A — service transport/evaluation rehearsal24/11/2026

Tái sử dụng Face pinfcabeba, buffalo_s riêng/CPU; operation binding/generation/staging/post-commit finalize/tombstone và signed capture proof. Backend remote chỉ protocol synthetic trên V13 hiện có; actual model/PAD/production threshold chưa admission. Không dữ liệu người thật mới hoặc migration/DB chung. [Contract/technical choices/recovery/giới hạn](backend-handover/decisions/2026-11-24_F03A_FACE_SERVICE.md), [chạy lại/evaluation dataset contract](backend-handover/24_FACE_SERVICE_QUICKSTART.md). Kết quả protocol và generated-input model smoke tách khỏi accuracy/PAD/camera.

## F03B — camera thủ công và evaluation, 24/11/2026

Người dùng cho chuẩn bị camera và dataset được phép, không tự ghi người thật. Chỉ lưu từng still sau consent + thao tác chủ động; dữ liệu ngoài Git. Tái sử dụng model/weights F03A, khóa identity/session split và threshold chọn từ calibration trước evaluation; không tự duyệt threshold production/PAD/admission. [Quyết định kỹ thuật và giới hạn](backend-handover/decisions/2026-11-24_F03B_CAMERA_EVALUATION.md), [hướng dẫn operator](backend-handover/25_FACE_CAMERA_EVALUATION_QUICKSTART.md).

## F03B tạm hoãn thu ảnh/accuracy —25/11/2026

Người dùng tạm hoãn thu ảnh và đánh giá người thật: **tooling ready; dataset/calibration/evaluation chưa chạy**. Operator đã báo camera preview ổn; không tự chuyển xác nhận camera thành consent. Không tạo study/mẫu/accuracy, không đổi threshold/liveness/admission. R01 chỉ khảo sát tích hợp main, không merge hoặc áp migration/DB chung. [R01 readiness và giới hạn](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md).

## R02 — portable guarded Core rehearsal, 25/11/2026

Người dùng cho sửa portable bootstrap/runner và tài liệu, không merge main/DB chung. Windows/Docker Desktop Linux/JDK21, PostgreSQL17.12 pin digest; mỗi máy sinh namespace/credentials/authority mới. Tái sử dụng frozen12SQL V1–V6,V8–V13, không tự chấp nhận SQL tìm thấy hoặc đổi migration/checksum. Default gates không thay; Face thật chưa nghiệm thu, simulator test-only. Fresh rehearsal khác upgrade/release: thiếu shared inventory/order/backfill thì releaseReady=false. [Setup/gates](INTEGRATION_SETUP.md), [inventory chỉ đọc](DB_INVENTORY.md).

## DB01 — compatibility candidate và nguồn kỳ, 25/11/2026

Theo task người dùng: giải quyết xung đột V7 trên DB test, chưa DB chung/main. **Đề xuất kỹ thuật đã rehearsal:** canonical `membership_paid_periods`, V7 source archive immutable/read-only view, compatibility callback trước pending migrations/V9/V11; V1–V13 nguyên bytes, V14 candidate ngoài default chưa là slot release. Không invent COUNTER/quote/date/receipt, không refund policy mới; missing source/conflict/refund cần reconcile trước import. Initial M03/Renewal locking/business rules giữ nguyên. [Hai đường/giới hạn/inventory](DB01_UPGRADE.md), [evidence](backend-handover/evidence/DB01_MIGRATION_COMPATIBILITY.md). Không coi đề xuất đã test là phê duyệt rollout DB chung hoặc sửa M04/consumer contract.

## Core main candidate — quyết định đã chốt25/11/2026

Người dùng toàn quyền: membership_paid_periods là nguồn kỳ cấp quyền duy nhất; M03 COUNTER/receipt/snapshots giữ nguyên. Fresh demo/dev V1–V6,V8–V13, không V7 rỗng/destructive, không V14/callback legacy không cần thiết. Version gap hợp lệ; không đổi bytes/checksum/version đã công bố, history/out-of-order/repair/clean. DB cũ đã V7 dùng compatibility có nguồn trước dependency rồi V14; missing provenance/refund/conflict báo rõ. Không có đích DB cũ thực tế thì targetUpgradeVerified=false, không chặn fresh demo. [Setup](INTEGRATION_SETUP.md), [upgrade](DB01_UPGRADE.md).

Core-demo là profile private guarded riêng; OTP/mail sink, quầy, renewal/Admin simulator bật rõ; Face check-in/enrollment/remote service tắt. Face accuracy/PAD/camera-to-admission người thật tiếp tục hoãn. M04 summary dùng đúng period plan UUID/live catalog name khi snapshot thiếu; history không dựng snapshot. Được commit/push ứng viên và draft PR main sau review/tests; chưa merge/deploy hoặc sửa DB chung. Các snapshot chờ Duy/gap7 release blockers ở trên không còn áp dụng cho fresh demo.
