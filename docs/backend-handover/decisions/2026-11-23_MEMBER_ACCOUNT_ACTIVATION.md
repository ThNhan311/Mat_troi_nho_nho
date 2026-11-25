# MEMBER account activation — quyết định và contract

Người dùng đã đồng ý quy trình trong M-03, sau đó giao triển khai riêng23/11/2026. Base M-03 `5399c5707288669997e898740daa36c57d04d632`, nhánh `feature/member-account-activation`.

## Phạm vi đã chốt

Member do Admin tạo chưa kích hoạt: email → OTP email5phút → verify → password → User ACTIVE → login email/password. Không cần có Membership; không tạo/kích hoạt/gia hạn Membership hay ghi thêm thanh toán. Không tự kích hoạt mọi DISABLED/legacy/suspended/completed user. Membership/account độc lập, giữ Booking/D01.

## API và bảo vệ

Ba POST public, không nhận Bearer hoặc role do client điều khiển:

| Endpoint | Input | Thành công |
|---|---|---|
| `/api/v1/auth/member-activation/request-otp` | email string hợp lệ <=255 |202 message chung, expiresInSeconds300, resendAfterSeconds60 |
| `/api/v1/auth/member-activation/verify-otp` | email, otp string6digits |200 verificationToken43chars, expiresInSeconds300 |
| `/api/v1/auth/member-activation/password` | verificationToken, password |200 status ACTIVE, không JWT |

Cache-Control no-store. Error envelope hiện có error.code/message/correlationId: ERR_ACTIVATION_NOT_READY503/default-off; ERR_ACTIVATION_INVALID400; ERR_OTP_EXPIRED400; ERR_OTP_ALREADY_USED409; ERR_OTP_ATTEMPT_LIMIT429; ERR_OTP_RESEND_TOO_SOON429; ERR_OTP_SEND_LIMIT429; ERR_VALIDATION400; ERR_TEST_MAIL_ONLY/ERR_TEST_MAIL_UNAVAILABLE503; ERR_CONFLICT409 cho DB concurrency/fault. Không echo OTP/grant/password hoặc SQL.

Dùng chung AccountActivationFlow/ActivationRequests/PasswordEncoder/Clock/mailer với PT; service wrappers vẫn là transaction boundary. Store chọn role/table/profile/audit event bằng enum allow-list server. PT và Member lưu state **hai bảng riêng**; grant lookup chỉ bảng của role, challenge luôn kiểm đúng User role. Composite FK(user_id,user_role) + CHECK role trong mỗi bảng chặn sai role ở DB. Không bỏ role PT để mở Member.

Eligibility: role đúng, profile tương ứng tồn tại, status DISABLED, audit ACCOUNT_CREATED_PENDING_ACTIVATION có details.role khớp và actor User role ADMIN. Không audit PT_ACCOUNT_ACTIVATED hoặc MEMBER_ACCOUNT_ACTIVATED; không completed_at. Admin list activationPending cũng loại cả hai completion markers. Không đòi actor tạo account vẫn ACTIVE ở lần kích hoạt sau, nhưng marker phải từ Admin; không tạo marker từ Member/public input.

Giữ contract PT: OTP SecureRandom6digits, BCrypt digest, TTL300s; đúng expiry không còn hiệu lực,5wrong attempts/challenge, resend>=60s và<=5lần/cửa sổ1giờ neo tại send_window_started_at, reset khi now>=windowStart+3600s. Sai OTP commit tăng attempt dù trả400; resend xóa grant cũ/resetattempt. Grant random32bytes Base64url43chars, SHA256 digest, TTL300s, một lần; không JWT. Password>=8Unicode codepoints,<=72UTF8bytes, không blank/truncation. Không lưu/log clear secret, DTO toString redacted.

Khóa User→role activation row, Clock sau khi có cả khóa. Request/save/SMTP failure rollback state; SMTP chỉ loopback và @example.invalid. Verify noRollbackFor ActivationFailure chỉ để commit wrong-attempt; DataAccess failure vẫn rollback. Password User ACTIVE+BCrypt+role activation completed/consume grant+audit một transaction. Request lặp không sửa metadata/completion; không retry write mù. SMTP không phải transaction phân tán: nếu SMTP đã nhận nhưng commit thất bại có thể có mail không dùng được, không được coi mail nhận là account đã ACTIVE.

M-03 giữ Member→membership→plan, không khóa User; activation không khóa Member/membership/payment. Test race hai thao tác độc lập chứng minh cả hai commit một lần, không vòng khóa; account activation không tăng/đổi Membership/payment/chứng từ.

## Database và phát hành

V10 tại `database/member-activation-rehearsal`, chỉ CREATE member_account_activation (FK/phase/counter/grant checks tương đương PT), không ALTER V8 table/constraints hoặc sửa V1–V6/V8/V9 đã apply. V7 database ref558fb03 còn DROP periods chưa backfill, không áp.

Profile `account-integration-rehearsal` có **một** Flyway strategy riêng, locations1–6 +8 +9 +10, migrate tăng dần `1,2,3,4,5,6,8,9,10`, outOfOrder=false/clean-disabled=true. Không bật đồng thời các profile rehearsal cũ để tranh strategy. Guard trước Flyway xác minh flag, JDBC127.0.0.1:15441, tên fitcenter_account_<nonce>_(empty|history)_test, role fitcenter_account_app không quyền admin và đúng4locations. M03 schema guard thêm nhánh integrated với guard đó; giữ guard15440 cũ. PT guard cũ vẫn chạy và bảngPT phải tồn tại.

Member/PT/M03 default vẫn false. Không tắt guard để chạy chung. History có gapV7 là **rehearsal test**, không DB release. Cần Duy thống nhất canonical order V7/V8/V9/V10 và backfill periods trước merge/release; không out-of-order/history edits/repair/clean hoặc sửa checksum. Mail production chưa có, không gửi người thật.

## Frontend

Login Member gốc thêm entry kích hoạt, dùng theme/form/navigation hiện có tương tự PT. Không bỏ qua login hoặc mock ACTIVE. Password chỉ hiện sau verify; OTP/password/grant memory-only, clear khi phase/session/dispose, epoch loại response cũ, busy chống double-submit. Network/write outcome unknown không replay; quay về login đối chiếu, muốn bắt đầu lại phải người dùng thao tác và chịu cooldown server. Session/login/JWT flow hiện có không đổi.

[Chạy lại](../19_MEMBER_ACCOUNT_ACTIVATION_QUICKSTART.md), [evidence](../evidence/MEMBER_ACCOUNT_ACTIVATION.md). M-03 quyết định chưa triển khai MEMBER activation nay được thay trong phạm vi rehearsal này; không suy ra production rollout hoặc renewal/payment gateway.
