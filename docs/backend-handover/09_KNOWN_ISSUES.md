# Vấn đề và rủi ro đã ghi nhận

| Vấn đề / trạng thái | Bằng chứng, ảnh hưởng, xử lý đề xuất |
|---|---|
| V7 / rủi ro chưa giải quyết, cao | Nhánh database riêng xóa cột period của payment; có thể mất lịch sử nếu áp dụng không chuyển dữ liệu. Đọc V7, đối chiếu dữ liệu trên bản sao được duyệt, thiết kế chuyển/kiểm tra trước phê duyệt. Không áp dụng tùy tiện. |
| Slot/booking / rủi ro thiết kế, cao | V4 không tự đồng bộ trạng thái hai bảng; chưa có write flow. Thiết kế transaction, khóa và test đồng thời; không khẳng định bug đang xảy ra. |
| PENDING/REJECTED / xung đột schema, cao | V4 CHECK chỉ cho CONFIRMED/CANCELLED/COMPLETED; tái hiện bằng cách đối chiếu CHECK với đề xuất duyệt. Chờ quyết định nhóm. |
| Danh sách không phân trang / giới hạn, vừa | Controller trả List; dữ liệu lớn có thể tăng tải. Xác định contract pagination trước thay đổi. |
| Kiểm thử / giới hạn, vừa | Kết quả Task 04 lịch sử, kiểm tra SQLSTATE 23505 riêng skipped, harness ngoài repo không tìm thấy. Tái kiểm thử DB riêng sau duyệt. |
| `backend/bin/` / untracked, thấp | Git status liệt kê IDE output; không stage hoặc xóa tự động. |
| Worktree database/frontend / chưa tích hợp, vừa | `git worktree list` có hai nhánh riêng; không giả định nội dung đã merge. Review diff và phối hợp chủ nhánh. |
| Nhầm database / cao | application-alignment có URL mặc định DB bảo vệ; Flyway bật khi khởi động. Kiểm tra profile/URL trước chạy, tạo DB riêng. |
| GitHub / cần đối chiếu lại, vừa | Kiểm tra trực tiếp ngày 18/11/2026 chưa thấy nhánh bàn giao; trạng thái có thể thay đổi. Đối chiếu trước công bố. |

## Phân loại

Chưa xác nhận bug mới trong lượt này. V7 và đồng bộ slot là design risk; thiếu phân trang là technical debt/giới hạn; PENDING/REJECTED là business blocker và xung đột schema; thiếu harness là giới hạn kiểm thử. Xem [V4](../../database/migrations/V4__pt_booking.sql), [POM](../../backend/pom.xml), [service](../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingQueryService.java).
