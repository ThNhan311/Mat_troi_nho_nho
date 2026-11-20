# Công việc cho người tiếp nhận

Backend hiện có login/refresh, đọc gói membership, membership của member, danh mục PT và availability, lịch booking riêng của member/PT. R01 bổ sung GET Admin Booking Policy trong working tree sau commit Task A 073e131. Xem [API](05_API_DOCUMENTATION.md) để biết role và tham số; tài liệu OpenAPI là bản nháp. Chưa có API ghi để quản lý slot, tạo/hủy/hoàn thành booking, cập nhật policy, activation/renewal hoặc payment.

Sau khi xác nhận contract và phạm vi với nhóm, xem [backlog](08_DEVELOPMENT_ROADMAP.md):

- **Booking Policy:** contract GET đã chốt và triển khai ở R01; cập nhật policy có hiệu lực ngay theo D05 là task sau, chưa có PUT. Quy tắc và phần còn thiếu được phân biệt tại [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md).
- **Booking lifecycle:** triển khai auto-confirm, membership eligibility, deadline và trạng thái slot theo D01–D07 đã chốt; chưa có các luồng ghi này. Không thêm PENDING/REJECTED.
- **Membership lifecycle và payment:** xác nhận activation tại quầy, renewal, thanh toán, idempotency và bảo toàn lịch sử.
- **V7:** nhánh database riêng có đề xuất membership periods và xóa cột kỳ thanh toán; cùng người phụ trách database/Nhân đối soát lịch sử và thiết kế migration trước bất kỳ áp dụng nào.
- **Face và module khác:** trao đổi Duy hoặc chủ module về dependency và phạm vi. Danh sách vấn đề cụ thể ở [blockers](07_BUSINESS_RULES_AND_BLOCKERS.md).

Trước mỗi commit: xác nhận task và business rule, đọc source/migration hiện tại, kiểm thử unit/MVC và integration trên DB riêng theo phạm vi, ghi skipped, review diff và dữ liệu nhạy cảm. Không tự sửa migration đã áp dụng, không kết nối DB bảo vệ, không coi các kết quả Task 04 lịch sử là test vừa chạy.
