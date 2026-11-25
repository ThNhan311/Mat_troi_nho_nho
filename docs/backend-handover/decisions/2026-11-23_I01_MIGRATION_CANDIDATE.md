# I-01 — ứng viên migration và điều kiện phát hành

Base ứng dụng `950311082d4cc5b2c5b85b1a3f8cd644246cd932`; database ref đã fetch `origin/feature/database-schema` tại `558fb03fd5927ca9e04d17b54fd46e429fe62bb5` (23/11/2026). [Manifest đầy đủ](../../../database/core-integration-candidate.json) chứa version/path/SHA-256 bytes worktree/SHA-256 Git blob/Flyway CRC32/phụ thuộc và SQL ở các remote refs đã biết. Khác CRLF/LF được ghi riêng; CRC32 là checksum Flyway thực tế đã đối chiếu với PostgreSQL. Không lấy SHA-256 thay cho Flyway checksum.

## Chuỗi được thực thi riêng trong rehearsal

| Version | Path / ngu?n | Flyway CRC32 | SHA-256 bytes (r?t g?n) | Ph? thu?c theo th? t? candidate | Tr?ng th?i |
|---|---|---:|---|---|---|
| 1 | [database/migrations/V1__core_users_members.sql](../../../database/migrations/V1__core_users_members.sql) | 1458726014 | `df40d5114a8c88f4` | ? | canonical; DB ri?ng ?? verify |
| 2 | [database/migrations/V2__membership_payment.sql](../../../database/migrations/V2__membership_payment.sql) | 989506803 | `dffe32d5fc343e6e` | 1 | canonical; DB ri?ng ?? verify |
| 3 | [database/migrations/V3__checkin.sql](../../../database/migrations/V3__checkin.sql) | -515824181 | `17a711675169667f` | 1,2 | canonical; DB ri?ng ?? verify |
| 4 | [database/migrations/V4__pt_booking.sql](../../../database/migrations/V4__pt_booking.sql) | 568475058 | `79844557f18bc878` | 1,2,3 | canonical; DB ri?ng ?? verify |
| 5 | [database/migrations/V5__workout_notification.sql](../../../database/migrations/V5__workout_notification.sql) | 1125685481 | `ad8d568c9cc57351` | 1,2,3,4 | canonical; DB ri?ng ?? verify |
| 6 | [database/migrations/V6__audit_log.sql](../../../database/migrations/V6__audit_log.sql) | -1514799074 | `486497e40e779250` | 1,2,3,4,5 | canonical; DB ri?ng ?? verify |
| 7 | `database/database/migrations/V7__membership_periods.sql` t?i database558fb03 | -349926232 | `668fdd672fdcff04` | 1,2 | quarantine, kh?ng ch?y |
| 8 | [database/activation-rehearsal/V8__pt_account_activation.sql](../../../database/activation-rehearsal/V8__pt_account_activation.sql) | -750065425 | `7f38b7f83662d489` | 1,2,3,4,5,6 | rehearsal; DB ri?ng ?? verify |
| 9 | [database/membership-rehearsal/V9__membership_initial_activation.sql](../../../database/membership-rehearsal/V9__membership_initial_activation.sql) | 2048807649 | `98783c7fcbfba450` | 1,2,3,4,5,6,8 | rehearsal; DB ri?ng ?? verify |
| 10 | [database/member-activation-rehearsal/V10__member_account_activation.sql](../../../database/member-activation-rehearsal/V10__member_account_activation.sql) | 1490426486 | `cf6d6918134409f5` | 1,2,3,4,5,6,8,9 | rehearsal; DB ri?ng ?? verify |

Manifest `dependsOn` còn liệt kê toàn bộ tiền nhiệm được đóng băng để thể hiện thứ tự chạy, không có nghĩa V9 phụ thuộc logic vào OTP PT. Không tạo V11, đổi số hoặc sửa bytes migration đã công bố. Default location vẫn chỉ V1–V6. Cùng profile `account-integration-rehearsal`, 4 locations chính xác, port15441, role riêng, guard trước Flyway; default gates PT/Member/M03 không đổi.

Đã biết áp dụng: chỉ các DB test riêng mà runner tạo và kiểm tra `flyway_schema_history` trong evidence I-01. Không suy rộng sang máy khác. Inventory shared/đồng đội/production **chưa được cung cấp, chưa xác minh**; V7 có thể đã áp ở đó. [SQL inventory chỉ đọc](../../../database/inventory/read-only-history.sql) dành cho chủ DB chạy sau khi có quyền; I-01 không kết nối DB chung.

## Vì sao chưa đưa V7 vào ứng viên release

V7 hiện DROP constraint `ck_payment_period` và hai cột payment periods trước khi tạo `membership_periods`; không có INSERT/backfill/đối soát. Giao dịch SUCCESS/FAILED/REFUNDED/CANCELLED/PENDING và payment chưa gắn membership đều có thể mất ngày cũ. V7 thêm `app_today()`, bảng periods, unique payment, exclusion overlap, unique ACTIVATION/membership, composite FK, trigger BEFORE INSERT và view `v_membership_overview`; thay mô tả `memberships.plan_id/expiry_date` thành semantics period. Không đổi kiểu ngày gốc hay cung cấp cơ chế phục hồi periods đã DROP.

M-03 hiện ghi COUNTER SUCCESS có payment + receipt/audit + snapshot/idempotency. V7 ACTIVATION bắt `payment_transaction_id IS NULL`; RENEWAL bắt payment nhưng cấm metadata thu quầy. Không được đổi mọi SUCCESS thành RENEWAL để ép schema. Java M-03 INSERT/read vẫn dùng payment periods; áp V7 nguyên bản sẽ làm hỏng đường ghi. M-04 vẫn đọc array memberships, chưa chuyển sang current/next-period view. V8/V10 role-state và V9 receipt/snapshot phải được giữ nguyên.

## Đường phát hành có điều kiện — chưa được thực thi

1. Thu inventory từng DB đích: actual version/script/checksum, biến thể V1–V6, V7 đã áp/chưa, dữ liệu legacy, backup và quy trình phục hồi. Không giả định published ref đồng nghĩa đã migrate.
2. Nếu DB còn V1–V6: **không chạy V7 hiện tại**. Cần thống nhất nhánh canonical/location và checksum với nhóm trước khi nâng. Có thể chọn release vẫn dùng legacy periods và additive V8/V9/V10; phải được đồng thuận rõ V7 bị loại khỏi release artifact, không âm thầm xóa/đổi published migration. History rehearsal có gap7 tự nó không phải release chain được duyệt.
3. Nếu V7 đã áp: giữ nguyên history/checksum. Cần nguồn backup/export để phục hồi period_start/end bị DROP; view mới không tự chứng minh đã bảo toàn dữ liệu cũ. Chỉ sau đối soát theo từng payment UUID mới thiết kế forward-only compatibility migration ở version cao hơn tất cả version thực tế; không repair/history edit hoặc tái áp V7. Không có dữ liệu gốc thì ghi rõ phần không phục hồi được, không bịa ngày từ membership hiện tại.
4. Nếu chọn period model: expand trước, giữ legacy cột, archive đầy đủ mọi status/null semantics; backfill có provenance/unique mapping, giữ receipt/snapshots và phân biệt initial COUNTER với renewal; đối chiếu từng payment UUID/date/amount và overlap. Chốt mapping initial-counter trước khi contract/drop. Chỉ contract legacy sau khi code đọc/ghi tương thích và bằng chứng bảo toàn được duyệt. Đây là đề xuất, chưa là migration được phép áp.
5. Flyway nâng từ history8/9/10 mà bổ sung V7 sẽ validation fail với outOfOrder=false. I-01 kiểm chứng fail này mà **không chạy DDL V7**. Không bật out-of-order hoặc sửa history để lách.

Cần đồng bộ với Duy: inventory DB thực tế và checksum V7; nguồn backfill đã mất/đang còn; mapping COUNTER initial; thứ tự/location/artifact V7–V10; lộ trình forward compatibility và rollback/backup. Không bị chặn kiểm thử riêng, nhưng **releaseReady=false** cho đến khi các mục này được giải quyết.
## T?i l?p bytes khi checkout

[.gitattributes](../../../.gitattributes) pin EOL th?c t? ?? ki?m: V1?V6/V9/V10 CRLF, V8 LF. ??y l? l?a ch?n t?i l?p artifact, kh?ng s?a content/versions c?a SQL ?? c?ng b?. Hai checkout v?o th? m?c tr?ng v?i core.autocrlf=true/false ??u gi? SHA-256 c?a9SQL theo manifest; kh?ng checkout ?? repository. [B?ng ch?ng](../evidence/I01_CHECKOUT_RESULTS.json).
