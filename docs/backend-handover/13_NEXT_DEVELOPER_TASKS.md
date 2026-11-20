# Công việc cho người tiếp nhận

Backend hiện có login/refresh, đọc gói membership, membership của member, danh mục PT và availability, lịch booking riêng của member/PT. R01 đã commit local 9ae0a50, bổ sung GET Admin Booking Policy. Working tree R02 thêm PT tạo/sửa/loại slot, bảo toàn lịch sử bằng DISABLED hoặc slot thay thế. Xem [API](05_API_DOCUMENTATION.md) để biết role và tham số; tài liệu OpenAPI là bản nháp. Chưa có API tạo/hủy/hoàn thành booking, cập nhật policy, activation/renewal hoặc payment.

Sau khi xác nhận contract và phạm vi với nhóm, xem [backlog](08_DEVELOPMENT_ROADMAP.md):

- **Booking Policy:** contract GET đã chốt và triển khai ở R01; cập nhật policy có hiệu lực ngay theo D05 là task sau, chưa có PUT. Quy tắc và phần còn thiếu được phân biệt tại [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md).
- **Booking lifecycle:** triển khai auto-confirm, membership eligibility, deadline và trạng thái slot theo D01–D07 đã chốt; chưa có các luồng ghi này. Không thêm PENDING/REJECTED.
- **Booking write tiếp theo:** giữ cùng thứ tự khóa PT → slot khi cần cả hai; phải khóa và kiểm tra lại AVAILABLE/ownership/time trong transaction trước insert CONFIRMED. Không bỏ qua giao thức khóa R02 hoặc chỉ dựa vào status đọc trước transaction; xem [giới hạn concurrency](decisions/2026-11-20_R02_AVAILABILITY.md).
- **Membership lifecycle và payment:** xác nhận activation tại quầy, renewal, thanh toán, idempotency và bảo toàn lịch sử.
- **V7:** nhánh database riêng có đề xuất membership periods và xóa cột kỳ thanh toán; cùng người phụ trách database/Nhân đối soát lịch sử và thiết kế migration trước bất kỳ áp dụng nào.
- **Face và module khác:** trao đổi Duy hoặc chủ module về dependency và phạm vi. Danh sách vấn đề cụ thể ở [blockers](07_BUSINESS_RULES_AND_BLOCKERS.md).

Trước mỗi commit: xác nhận task và business rule, đọc source/migration hiện tại, kiểm thử unit/MVC và integration trên DB riêng theo phạm vi, ghi skipped, review diff và dữ liệu nhạy cảm. Không tự sửa migration đã áp dụng, không kết nối DB bảo vệ, không coi các kết quả Task 04 lịch sử là test vừa chạy.
