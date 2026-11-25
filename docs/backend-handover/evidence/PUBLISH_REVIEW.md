# Review trước commit/push —22/11/2026

Người dùng cho phép commit/push phần đã review lên nhánh chức năng riêng; chưa merge, không force-push hoặc áp migration. Remote origin: https://github.com/ThNhan311/Mat_troi_nho_nho.git. Nhánh đích **feature/admin-account-pt-activation**, bắt đầu1b1e323; M-01 đóng riêng **6fbf9fc5bf86690a7e1d792738f6120a9038db63**, account là commit kế tiếp chứa ghi chú này. Xem SHA cuối bằng Git local/remote, không ghi hash tự tham chiếu trong nội dung commit.

## Tách scope và bảo toàn source

- M-01:25file theo registry evidence,12executable working hashes khớp mốc đã test. Sáu file dùng chung (AdminHome/API/OpenAPI/testing/quickstart/traceability) được stage từ snapshot index riêng; Home khôi phục chính xác hash M-01. Không sửa/checkout/reset/stash source working tree để tách commit. Index chuẩn hóa CRLF→LF theo cấu hình Git, không đổi executable logic.
- Account/PT:48file scope đã review + tài liệu này;30executable hashes khớp evidence. Giữ Admin Home thêm account route ở commit này. API/public paths cụ thể, default activationfalse; **ERR_ACTIVATION_NOT_READY503** đến khi schema thống nhất. Candidate SQL chỉ ở docs/proposals, không phải migration canonical và chưa áp. Không đưa membership activation/renewal/payment hoặc MEMBER activation vào scope.
- Bốn research untracked giữ nguyên hashes, không stage/publish; một số links research trong docs cần các file local này. Không thay source/Face ở checkout gốc hoặc branch đồng đội. Không build/cache/SDK/raw logs/private manifest/credential trong staged scope.

## Review và bằng chứng

[M-01](M01_PLAN_CREATE.md): Backend720/Admin63, UI16/HTTP3/DBaudit3 là kết quả đã chạy trước account. [Account](ACCOUNT_PT_ACTIVATION.md): Backend762/Admin73/PT55, UI16/HTTP1/DBaudit3 và SMTPloopback test thật. Focused là tập con, không cộng dồn. Không chạy lại tests/build khi executable source không đổi. Metadata evidence workingTree/committed=false/HEAD1b1e323 là snapshot lúc kiểm thử, không phải trạng thái Git sau commit/push.

Đã đối chiếu hashes executable/dependencies/ảnh/research, review diff/source/scripts/docs và ảnh tổng hợp. Scan staged scope và11commit nền chưa remote cho exactprivate credentials, JWT/private key; không phát hiện. Vectors synthetic trong tests không phải credentials thật. Không log/lưu credential Git; token chỉ memory để đọc CI/CD. Source hashes là bytes working tree; blob Git có thể khác chỉ do EOL normalization, được đối chiếu riêng khi stage. API OpenAPI26paths/171localrefs và context links đã kiểm tra; bốn research chưa xuất bản là giới hạn được ghi rõ.

## Remote và CI/CD kiểm trước thao tác

Fetch origin --no-tags thành công; nhánh đích chưa tồn tại remote. Chỉ tạo branch chức năng mới, không cập nhật main/backend/frontend/database/shared refs. Ngoài2commit mới, nhánh mang theo11commit nền local từ073e131 đến1b1e323 (Booking/D01/Web/AdminPolicy); không rewrite hoặc merge các commit này.

Không có CI/config deployment trong source task/current/main. GitHub API đã xác thực: **0Actions workflows,0workflow runs,0deployments,0webhooks**. Local0customhooks, không bỏ hooks/signing. Không suy ra CI xanh hoặc deployment từ test local. Sau push phải kiểm ls-remote khớp HEAD, upstream ahead/behind0/0; kiểm Actions theo SHA cuối, báo kết quả thực.

## Bàn giao

Đọc [PROJECT_STATUS](../../PROJECT_STATUS.md) và [DECISIONS](../../DECISIONS.md). Bước phát triển tiếp theo cần Duy thống nhất schema OTP; chưa chứng minh activation PostgreSQL concurrency/rollback hoặc email production. Fixture/process demo đã cleanup/dừng từ lượt trước, volume giữ nguyên; lượt publish không khởi động DB hoặc apply DDL. Kết quả push/SHA/remaining files được báo trực tiếp sau thao tác.
