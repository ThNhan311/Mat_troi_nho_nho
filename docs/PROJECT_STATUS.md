# FitCenter — trạng thái tiếp tục

Cập nhật22/11/2026 trước commit account. Worktree **Mat_troi_nho_nho-booking-integration**, branch **feature/admin-account-pt-activation**, HEAD tại thời điểm cập nhật **6fbf9fc5bf86690a7e1d792738f6120a9038db63**. HEAD sẽ đổi khi đóng commit account chứa tài liệu này; luôn xác minh Git khi tiếp tục.

## Đã hoàn thành và kiểm chứng

M-01 Admin plan create/read trên UI gốc đã đóng riêng tại6fbf9fc, đúng25file;12executable hashes khớp evidence cũ. [Báo cáo M-01](backend-handover/evidence/M01_PLAN_CREATE.md).

Admin tạo/list Member/PT account DISABLED trên UI gốc; User+profile+audit nguyên tử, không membership/payment hoặc JWT login trước ACTIVE. PT core/client/UI email→OTP5phút→verify→password→ACTIVE đã chuẩn bị nhưng **gate503 mặc định**, chưa nghiệm thu activation HTTP/PostgreSQL. [Contract/schema](backend-handover/decisions/2026-11-22_ACCOUNT_PT_ACTIVATION.md), [quyết định chung](DECISIONS.md).

Evidence từ source working tree trước commit: Backend762 passed,0failed/errors/skipped; Admin73/PT55 passed; hai Web build thành công; analyzer0error/0warning,44/59info (--no-fatal-infos). Chrome thật16UI checks,1HTTP riêng,DBaudit3; SMTPunit3 gồm1delivery loopback. Không cộng focused; không dùng kết quả này như CI vừa chạy. Executable source không đổi, không chạy lại tests chỉ để commit. [Evidence/hashes](backend-handover/evidence/ACCOUNT_PT_ACTIVATION.md).

## Git, quyền mới và xuất bản

Người dùng đã cho phép stage từng file, commit và push phần review lên nhánh chức năng riêng; **không merge/force-push/apply migration**. Account là commit sau M-01, chứa context/docs/SQL candidate chỉ review và evidence. Snapshot evidence trước commit giữ nguyên lịch sử; xem [review xuất bản](backend-handover/evidence/PUBLISH_REVIEW.md) để phân biệt.

Bốn tài liệu research vẫn untracked ngoài phạm vi; các liên kết research chỉ dùng được trong local working tree đến khi xuất bản riêng. Không đưa Face/SDK/cache/build/private credential/manifest/raw logs vào commit. Checkout gốc backend-service-eligibility089b5e2 và Face giữ nguyên. Fixture đã cleanup exactUUID; process/DB task đã dừng, volume giữ nguyên.

Remote origin là ThNhan311/Mat_troi_nho_nho. Kiểm tra GitHub xác thực trước push:0Actions workflows/runs,0deployments,0webhooks; local không custom commit/push hooks. Không có CI chạy để thay bằng evidence local. Nhánh chức năng chưa tồn tại remote tại lúc kiểm tra. Bước cuối: push thường, đối chiếu local/remote SHA và upstream; kết quả Git/remote là nguồn chuẩn, tài liệu này là snapshot trước commit.

## Blocker và bước tiếp theo

Canonical V1–V6 chưa có bảng OTP/grant/counter. Ref origin/feature/database-schema558fb03 có V7 membership periods; không áp V7 hoặc candidate, không clean/repair/alignment. [SQL candidate chỉ review](backend-handover/proposals/account_activation_candidate.sql).

Cần Duy thống nhất canonical path/version/checksum và version forward cho schema OTP. Sau đó mới migration rehearsal DB test riêng và chạy activation HTTP+PG (expiry/attempt/resend/verify/password/races/rollback), mail test/UI hoàn chỉnh. Chưa triển khai MEMBER activation, production SMTP, Membership/Payment/Face/Workout. Không bật flag để lách blocker. Đọc [AGENTS](../AGENTS.md) trước khi tiếp tục.
