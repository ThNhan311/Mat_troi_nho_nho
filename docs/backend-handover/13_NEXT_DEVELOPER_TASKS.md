# Công việc cho người tiếp nhận

Cập nhật R04: R03 đã commit `394a21f`; working tree có Member/PT cancel và PT complete. Người dùng đã chốt PT chỉ hủy trước startAt; endpoint và tests được bổ sung sau quyết định. [Contract và lock R04](decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md), [kết quả](evidence/R04_BOOKING_LIFECYCLE.md) là trạng thái hiện tại; đoạn R03 bên dưới là checkpoint trước lifecycle. D01 service-start check vẫn cần triển khai riêng.

Backend hiện có login/refresh, đọc gói membership, membership của member, danh mục PT và availability, lịch booking riêng của member/PT. R01 9ae0a50 có GET Admin Booking Policy; R02 4d137d7 có PT tạo/sửa/loại slot. Working tree R03 thêm Member booking auto-confirm, eligibility/membership/policy và concurrency; xem [báo cáo R03](evidence/R03_BOOKING_CREATE.md). [API](05_API_DOCUMENTATION.md) ghi contract hiện tại. Chưa có hủy/hoàn thành booking, cập nhật policy, activation/renewal hoặc payment.

Sau khi xác nhận contract và phạm vi với nhóm, xem [backlog](08_DEVELOPMENT_ROADMAP.md):

- **Booking Policy:** contract GET đã chốt và triển khai ở R01; cập nhật policy có hiệu lực ngay theo D05 là task sau, chưa có PUT. Quy tắc và phần còn thiếu được phân biệt tại [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md).
- **Booking lifecycle:** create có R03; Member/PT cancel và PT complete có R04 working tree. Recheck membership trước bắt đầu dịch vụ chưa có. Làm theo D01–D07, không thêm PENDING/REJECTED.
- **Booking write tiếp theo:** giữ Member → membership nếu cần → PT → slot → booking nếu cần. Lifecycle R04 bỏ membership vì không dùng eligibility; re-read Booking sau khóa cuối. Các writer thay count/overlap phải phối hợp Member lock. Không retry mù hoặc tác động slot từ request cũ; xem [giao thức R04](decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md).
- **Membership lifecycle và payment:** xác nhận activation tại quầy, renewal, thanh toán, idempotency và bảo toàn lịch sử.
- **V7:** nhánh database riêng có đề xuất membership periods và xóa cột kỳ thanh toán; cùng người phụ trách database/Nhân đối soát lịch sử và thiết kế migration trước bất kỳ áp dụng nào.
- **Face và module khác:** trao đổi Duy hoặc chủ module về dependency và phạm vi. Danh sách vấn đề cụ thể ở [blockers](07_BUSINESS_RULES_AND_BLOCKERS.md).

Trước mỗi commit: xác nhận task và business rule, đọc source/migration hiện tại, kiểm thử unit/MVC và integration trên DB riêng theo phạm vi, ghi skipped, review diff và dữ liệu nhạy cảm. Không tự sửa migration đã áp dụng, không kết nối DB bảo vệ, không coi các kết quả Task 04 lịch sử là test vừa chạy.
