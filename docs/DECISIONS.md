# Quyết định FitCenter

Nguồn chuẩn: yêu cầu người dùng của phiên, Topic11 và tài liệu quyết định chi tiết. Các bảng đề xuất trong [khảo sát](backend-handover/research/2026-11-22_CORE_MEMBERSHIP_PAYMENT_SURVEY.md) chưa tự trở thành quyết định.

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

- Canonical V1–V6 không có bảng OTP/grant/counter. Chuẩn bị SQL candidate ở docs/backend-handover/proposals, không tên V7/V8, không tự apply hoặc sửa guards. V7 của Duy558fb03 là membership periods và còn rủi ro DROP chưa backfill: [review](backend-handover/research/2026-11-22_DATABASE_V7_REVIEW.md).
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
