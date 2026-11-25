# Inventory DB hiện hữu — chỉ đọc, dành cho người quản lý DB

[R02 setup](INTEGRATION_SETUP.md#fresh-install-và-upgrade), [SQL inventory](../database/tools/read-only-inventory.sql). R02 **không kết nối DB dùng chung**. Người quản lý chọn đúng đích/tài khoản read-only và kiểm backup/policy chia sẻ trước khi chạy. Không gửi credential hoặc dữ liệu cá nhân vào chat/Git.

```powershell
# PGHOST/PGPORT/PGDATABASE/PGUSER do owner xác minh; password qua cơ chế local an toàn.
# Không đặt password trong command line hoặc file báo cáo.
psql -X -v ON_ERROR_STOP=1 -f database/tools/read-only-inventory.sql -o $privateInventoryOutput
```

SQL dùng transaction REPEATABLE READ READ ONLY, statement_timeout10s, chỉ catalog và aggregates. Không thay Flyway history/DDL/dữ liệu, không gọi clean/repair/out-of-order hoặc migration. Nếu thiếu quyền/object khác, dừng và báo đúng lỗi; không cấp superuser hoặc sửa SQL để giả lịch sử. Không dump email/password/OTP/grant/token/biometric template.

Cần đối chiếu: version/script/checksum/success, các bảng/cột/constraints/indexes, payment period columns còn hay đã drop, receipt/snapshot và paid-period model, activation-state tables, backups/migration commits đã dùng. File output giữ private; chỉ chia sẻ metadata đã review với nhóm Database. Inventory không chứng minh dữ liệu đã bị DROP có thể phục hồi.

Phân nhánh kế hoạch:

- DB trống: chỉ chạy một chuỗi canonical release đã thống nhất. Rehearsal V1–V6,V8–V13 của R02 không tự trở thành release chain.
- DB V1–V6: cần kế hoạch backfill bảo toàn periods/receipts/snapshots và version/order trước bật Account/Membership write.
- DB đã áp V7 hoặc V8+: giữ nguyên script/checksum/history đã áp; đối chiếu backup và forward corrective migration được phối hợp. Không rewrite/renumber V7–V13 hoặc bật out-of-order để ghép các history khác nhau.

Thiếu inventory thì **releaseReady=false**. V7 trên ref Database558fb03 DROP2payment period columns trước backfill và khác model M03/V11, không được áp chỉ để làm demo chạy. Portable rehearsal chỉ dùng test resources mới có guard; không tái sử dụng DB này.

DB01 bổ sung [inventory bắt buộc expected database/role và so hai model](../database/tools/db01-read-only-inventory.sql), cùng [hướng dẫn từng target và hai đường upgrade](DB01_UPGRADE.md). Chưa có target DB chung được xác định; không chạy SQL/upgrade theo phỏng đoán.
