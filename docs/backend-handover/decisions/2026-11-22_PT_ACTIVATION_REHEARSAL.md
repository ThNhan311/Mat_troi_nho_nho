# PT activation — schema và rehearsal riêng, 22/11/2026

Quyền mới của người dùng thay giới hạn chờ schema trong phạm vi DB test riêng: được tạo/apply migration test, hoàn thiện HTTP/PostgreSQL/mail sink/UI và commit/push nhánh chức năng. Không thay DB chung/production, không merge, không áp V7 membership periods. Quy trình nghiệp vụ account/OTP của [quyết định trước](2026-11-22_ACCOUNT_PT_ACTIVATION.md) giữ nguyên. [Evidence](../evidence/PT_ACTIVATION_POSTGRES.md).

## V8 và thứ tự phát hành

Canonical [V1–V6](../../../database/migrations) giữ nguyên. Fetch database ref mới nhất vẫn `558fb03fd5927ca9e04d17b54fd46e429fe62bb5`, có V7 membership periods dưới path database/database/migrations; chưa có V8 tại ref này. Chọn [V8__pt_account_activation.sql](../../../database/activation-rehearsal/V8__pt_account_activation.sql), chỉ ở location rehearsal riêng. Đây là migration chạy được trong DB test, không chỉ còn SQL proposal; không tự đưa vào canonical.

Maven package V1–V6 vào db/migration như cũ và V8 vào db/activation-rehearsal. Profile mặc định không resolve V8, activation vẫn false/503. Profile `activation-rehearsal` mới resolve hai location và bật activation test; `outOfOrder=false`, validate-on-migrate và cleanDisabled trong rehearsal tests. Runner kiểm canonical chỉ đúng sáu file và không khác baseline 66a7031 trước khởi động; JAR được kiểm nguồn/checksum và hai location trước ServeBackend.

Áp V8 trên V1–V6 sẽ có history 1,2,3,4,5,6,8. V7 được đưa vào sau có thể bị Flyway từ chối vì resolved migration chưa áp nằm dưới version hiện tại. Đã chứng minh bằng probe V7 gọi migrate nhưng bị chặn trước SQL; V7 thật của Duy chỉ được resolve/validate, không thực thi. Không out-of-order, ignore-pattern mới, clean, repair hoặc sửa history. V9999 fault probe chỉ là file tạm riêng để kiểm rollback DDL; không canonical hoặc version phát hành và không tồn tại trong history sau rollback.

**Trước merge/release:** đồng bộ version/path/checksum với Duy; production đi theo thứ tự canonical đã chốt (V7 rồi V8 nếu giữ hai số này). Không dùng DB rehearsal đã có V8 để chứng nhận upgrade V7 sau đó; tạo DB test mới theo thứ tự release để rehearsal lại. Không renumber migration đã áp trên DB chung. V7 hiện DROP payment period_start/period_end không backfill, rủi ro dữ liệu/query riêng vẫn cần xử lý trước release; task này không áp hoặc sửa V7.

## Review schema theo JDBC

Một bảng mới, 11 cột: user_id, user_role, otp_digest, otp_expires_at, attempts, send_window_started_at, send_count, last_sent_at, grant_digest, grant_expires_at, completed_at. Không sửa/drop cột hoặc bảng membership/payment.

- PK user_id là mutex state theo User; composite FK (user_id,user_role) → users(id,role) và CHECK user_role=PT. JDBC INSERT không gửi user_role, dùng default PT.
- BCrypt digest OTP vừa VARCHAR(100); expiry TIMESTAMPTZ. Không lưu OTP rõ. attempts SMALLINT 0..5; send_count 1..5, window/lastSent bắt buộc.
- Grant chỉ SHA256 hex64, CHAR(64) nullable UNIQUE để lookup không mơ hồ. CHECK digest/expiry cùng null hoặc cùng có; không đồng thời OTP+grant; completed row không còn digest/grant. Không backfill legacy DISABLED, không cascade xóa lịch sử.
- JDBC lock User → state, kể cả lần đầu state chưa có. Clock lấy sau khóa, verify sai commit attempts, verify đúng tiêu thụ OTP; password/ACTIVE/completed/audit cùng transaction. Code nghiệp vụ không đổi trong task này, đã được kiểm trực tiếp trên PostgreSQL.

## Cấu hình test và an toàn đích

Container mới `fitcenter-activation-20261122-db`, volume mới `fitcenter_activation_20261122_data`, bind127.0.0.1:15439. Mỗi lượt tests tạo hai DB mới `fitcenter_activation_<nonce>_empty_test` và `_history_test`, owner app không quyền superuser/createDB/createRole/replication/bypassRLS. Không dùng DB chung. Baseline regression V1–V6 vẫn chạy qua guarded runner cũ trên container baseline đã xác minh, không đưa V8 vào đó.

FlywayMigrationStrategy của profile rehearsal kiểm runner flag, JDBC URL host/port/name và role/privilege trước migrate; từ chối location khác hoặc out-of-order. ActivationSchemaGuard từ chối bật ngoài rehearsal, và yêu cầu table đã có. Mọi credential/manifest/raw logs ở private Temp; JVM UTC. SMTP adapter vẫn cố định loopback và recipient @example.invalid, không production mail. CORS chỉ localhost3001/3002 cho process demo này.

## Kết luận trong phạm vi test

Đã có schema rehearsal empty/history, HTTP + PostgreSQL + SMTP thật và UI email → OTP → password → ACTIVE → login/re-login. [Evidence cuối](../evidence/PT_ACTIVATION_POSTGRES.md) tách tests/checks và hashes. Không suy ra production ready, MEMBER activation, Membership/Payment hay toàn bộ FitCenter E2E. Không còn blocker phải chờ Duy để kiểm thử riêng; đồng bộ Duy là điều kiện release/merge, không dừng công việc test đã được giao.
