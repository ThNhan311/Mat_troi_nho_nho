# Công việc cho người tiếp nhận

Backend hiện có login/refresh, đọc gói membership, membership của member, danh mục PT và availability, lịch booking riêng của member/PT. R01 9ae0a50 có GET Admin Booking Policy; R02 4d137d7 có PT tạo/sửa/loại slot. Working tree R03 thêm Member booking auto-confirm, eligibility/membership/policy và concurrency; xem [báo cáo R03](evidence/R03_BOOKING_CREATE.md). [API](05_API_DOCUMENTATION.md) ghi contract hiện tại. Chưa có hủy/hoàn thành booking, cập nhật policy, activation/renewal hoặc payment.

Sau khi xác nhận contract và phạm vi với nhóm, xem [backlog](08_DEVELOPMENT_ROADMAP.md):

- **Booking Policy:** contract GET đã chốt và triển khai ở R01; cập nhật policy có hiệu lực ngay theo D05 là task sau, chưa có PUT. Quy tắc và phần còn thiếu được phân biệt tại [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md).
- **Booking lifecycle:** create auto-confirm/eligibility khi đặt đã có R03; cancel/complete, recheck membership trước bắt đầu dịch vụ và deadline cancel vẫn chưa triển khai. Làm theo D01–D07, không thêm PENDING/REJECTED.
- **Booking write tiếp theo:** giữ thứ tự khóa Member → membership → PT → slot khi cần các tài nguyên này; PT → slot của R02 vẫn giữ nguyên. Các writer thay count/overlap Member phải phối hợp khóa Member. Không retry mù, không bỏ kiểm tra sau khóa; xem [giao thức R03](decisions/2026-11-20_R03_BOOKING_CREATE.md).
- **Membership lifecycle và payment:** xác nhận activation tại quầy, renewal, thanh toán, idempotency và bảo toàn lịch sử.
- **V7:** nhánh database riêng có đề xuất membership periods và xóa cột kỳ thanh toán; cùng người phụ trách database/Nhân đối soát lịch sử và thiết kế migration trước bất kỳ áp dụng nào.
- **Face và module khác:** trao đổi Duy hoặc chủ module về dependency và phạm vi. Danh sách vấn đề cụ thể ở [blockers](07_BUSINESS_RULES_AND_BLOCKERS.md).

Trước mỗi commit: xác nhận task và business rule, đọc source/migration hiện tại, kiểm thử unit/MVC và integration trên DB riêng theo phạm vi, ghi skipped, review diff và dữ liệu nhạy cảm. Không tự sửa migration đã áp dụng, không kết nối DB bảo vệ, không coi các kết quả Task 04 lịch sử là test vừa chạy.
