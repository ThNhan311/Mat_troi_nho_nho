# Admin account và PT first activation — 22/11/2026

Nguồn quyết định là yêu cầu người dùng của task hiện tại; [khảo sát UC/schema](../evidence/R01_MAIN_INTEGRATION_READINESS.md) và [V7 Duy](2026-11-23_I01_MIGRATION_CANDIDATE.md) là bối cảnh, không thay thế quyết định. [Trạng thái ngắn](../../PROJECT_STATUS.md), [evidence](../evidence/ACCOUNT_PT_ACTIVATION.md).

## Đã chốt và phạm vi

Admin tạo account chưa kích hoạt, User + đúng một Member/PT profile trong cùng transaction. Không tạo membership/payment. Chỉ PT có luồng kích hoạt lần đầu: nhập email → nhận OTP email có hiệu lực 5 phút → verify → được đặt mật khẩu → ACTIVE → login email/password. Chưa quyết định hay triển khai Member activation. Không JWT thông thường cho DISABLED. Giữ UI/theme/navigation gốc; edit/status/delete account chưa khả dụng.

## Contract account chạy trên V1–V6

| API | Input / response | Quyền |
|---|---|---|
| POST /api/v1/admin/members | email, fullName → 201 AccountResponse MEMBER | ADMIN ACTIVE |
| POST /api/v1/admin/personal-trainers | email, fullName → 201 AccountResponse PT | ADMIN ACTIVE |
| GET hai đường dẫn trên | 200 array AccountResponse theo role | ADMIN ACTIVE |

Chỉ nhận hai JSON string, email không blank/@Email/tối đa255, fullName không blank/tối đa150 codepoints theo VARCHAR PostgreSQL. Reject field khác/null/sai kiểu/U+0000. User/profile UUID server khác nhau, role từ endpoint, status DISABLED. AccountResponse gồm userId/profileId/email/fullName/role/status/activationPending; không hash/password/JWT. Dùng constraint unique email case insensitive sẵn có, conflict409 ERR_CONFLICT; lỗi validation400/401/403 theo envelope hiện có. POST không idempotent: không replay khi chưa rõ kết quả; GET đối chiếu, không suy ra thành công chỉ từ tên/email.

Transaction10giây recheck actor ADMIN ACTIVE như convention M-01, INSERT/flush User/profile và V6 audit ACCOUNT_CREATED_PENDING_ACTIVATION nguyên tử. Placeholder BCrypt ngẫu nhiên mạnh, không bàn giao. Dấu audit chỉ áp account mới từ API, không tự cho mọi legacy DISABLED kích hoạt. Khi có PT_ACCOUNT_ACTIVATED thì không còn pending, kể cả sau này bị disable.

## Contract PT activation đã chuẩn bị, đang gate503

Ba POST public chính xác dưới /api/v1/auth/pt-activation; JSON string strict, response thành công/lỗi nghiệp vụ no-store, không Bearer/no-refresh/no tự replay:

| Suffix | Input | Success khi đã được phép bật |
|---|---|---|
| request-otp | email | 202 message chung, expiresInSeconds300,resendAfterSeconds60; không xác nhận email tồn tại |
| verify-otp | email,otp (6 số) | 200 verificationToken grant opaque43ký tự,expiresInSeconds300 |
| password | verificationToken,password | 200 status ACTIVE; không JWT |

Hiện **fitcenter.activation.enabled=false mặc định**. Cả ba trả503 ERR_ACTIVATION_NOT_READY; không query bảng OTP hoặc gửi mail. Startup guard từ chối bật nếu thiếu bảng; guard không apply DDL. Không bật flag trong quickstart, không lách Flyway/test guard.

Giới hạn kỹ thuật: SecureRandom6số, digest BCrypt, hết hạn khi now>=issued+300s; tối đa5 lần thử sai/challenge. Resend>=60s, tối đa5 sends/account/giờ; đúng mốc được phép, resend xóa grant cũ. Verify đúng tiêu thụ OTP, cấp32byte random base64url, chỉ lưu SHA256, TTL300s một lần. Password>=8codepoints,<=72byteUTF-8 để tránh BCrypt truncate, không composition rule mới. Không audit/log/email password hoặc log OTP/grant.

Khóa User → activation row trong mỗi transaction; User tồn tại là mutex cả khi chưa có activation row. Sau khóa recheck PT/DISABLED/audit marker/completed; Clock lấy sau chờ khóa. Grant lookup trước khóa chỉ để tìm User, sau khóa kiểm digest/expiry lại. Verify sai dùng noRollbackFor cho expected ActivationFailure để commit attempts; lỗi DB vẫn rollback. Complete cập nhật BCrypt/ACTIVE + clear grant/completedAt + audit cùng transaction. Không khóa Member/membership/PT profile/slot/policy, không đảo thứ tự Booking. Chưa chứng minh concurrency/rollback thực trên PostgreSQL cho activation; unit chỉ xác minh logic/order/Clock.

SMTP adapter hiện chỉ localhost127.0.0.1, test port1025 và recipient @example.invalid; không production SMTP. SMTP sync có timeout, mail failure rollback state; SMTP delivery và DB commit không distributed atomic, mail có thể đến nhưng transaction sau đó thất bại. Không tuyên bố exactly-once delivery; code chỉ dùng digest đã commit mới verify được. Mail test dùng in-memory sink, không ghi body/log OTP.

## Schema cần thống nhất với Duy trước khi tiếp tục

[SQL candidate](../proposals/account_activation_candidate.sql) chỉ review, **không canonical migration, chưa apply, không giữ chỗ V7/V8**. Thêm đúng1bảng pt_account_activation với11cột: user_id,user_role,otp_digest,otp_expires_at,attempts,send_window_started_at,send_count,last_sent_at,grant_digest,grant_expires_at,completed_at. PKuser_id; composite FK(users.id,role)PT; unique nullable grant_digest; CHECK counter/digest-expiry pairs/phases/completed. Không sửa/drop bảng/cột cũ, không backfill legacy DISABLED. Bảng mới trống trên DB trống hoặc DB có lịch sử.

Duy cần xác nhận: (1) canonical path và phiên bản/checksum đã áp thật, (2) phiên bản forward không đụng V7 membership periods tại558fb03, (3) chấp nhận bảng/retention completed row và marker V6 audit. V7 hiện có DROP payment period không backfill là rủi ro riêng, không bị task này tự xử lý. Sau thống nhất: tạo migration forward đúng version, rehearsal DB test riêng cả empty/history, kiểm FK/CHECK và HTTP/PG race verify/password/resend, rồi mới bật adapter test/flag. Chưa chạy clean/repair/alignment hoặc áp candidate.

## Frontend

Admin Home → Hội viên & PT dùng screen gốc, list/segmented/filter/modal tạo thật; unknown write khóa gửi lại, GET đối chiếu; epoch/nested navigation loại response/modal phiên cũ. PT login gốc thêm đường kích hoạt, password form chỉ sau verify200 hợp lệ; grant chỉ memory, logout/session change xóa dữ liệu, không tự login. Schema gate hiển thị chưa sẵn sàng, không giả đã gửi OTP. Membership/Payment/Workout/Face không thay đổi.
