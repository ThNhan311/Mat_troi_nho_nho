# Quyết định booking D01 đến D07

Ngày chốt: 20/11/2026. Nguồn phê duyệt: người dùng xác nhận trực tiếp D01–D07 trong phiên tiếp nhận backend, đồng thời chỉ định **Topic11** là nguồn của quy trình booking auto-confirm. Chưa có bản Topic11 trong checkout để dẫn trang/mục hoặc trích nguyên văn; nội dung dưới đây ghi đúng quyết định được cung cấp, không giả định đã audit toàn bộ Topic11.

Baseline: `8eebb9b`. Task A đã đóng bằng commit local `073e131b718bdce780f338b69dd4c039b14644f9`; R01 phát triển trên nhánh `feature/backend-booking-policy-read`, chưa commit.

## Quy tắc đã chốt và phạm vi triển khai

| Quyết định | Quy tắc đã được phê duyệt | Trạng thái trong R01 |
|---|---|---|
| Auto-confirm theo Topic11 | Booking được xác nhận tự động; không thêm PENDING/REJECTED | Giữ enum/schema hiện có. Chưa triển khai tạo booking |
| D01 | Membership ACTIVE lúc đặt và bao phủ toàn bộ session; kiểm tra lại trước khi bắt đầu dịch vụ | Chưa triển khai kiểm tra eligibility/luồng bắt đầu dịch vụ |
| D02 | Policy ban đầu: max advance 14 ngày, min notice 2 giờ, cancel deadline 4 giờ, tối đa 5 booking tương lai CONFIRMED | DTO đọc giá trị từ DB. 14/2/4/5 chỉ là fixture/ví dụ, không tự seed/default hoặc áp vào booking |
| D03 | Chấp nhận đúng bằng các mốc thời gian | R01 áp effective_from <= now, bao gồm equality. Các ranh giới notice/advance/cancel/complete chờ luồng ghi tương ứng |
| D04 | Không có policy hiệu lực: GET 404; từ chối booking; không tự áp default | GET 404 BOOKING_POLICY_NOT_FOUND đã triển khai; từ chối booking chưa triển khai vì chưa có booking write |
| D05 | Giai đoạn đầu chỉ cập nhật có hiệu lực ngay; hoãn scheduling và quản lý phiên bản đầy đủ | Chỉ GET; không có PUT hoặc scheduling. GET vẫn loại mọi row có effective_from trong tương lai |
| D06 | Nghiệp vụ Asia/Ho_Chi_Minh; lưu UTC; max advance là thời lượng 14 × 24 giờ | effectiveFrom trả UTC; Clock được inject. Chưa áp phép tính max advance vào booking |
| D07 | PT cancel làm slot DISABLED. Chỉ complete từ CONFIRMED khi now >= endAt, lưu completedAt; không mở lại slot đã qua | Fixture PT-cancel dùng DISABLED. Chưa có cancel/complete write hoặc tự đồng bộ slot |

Các quyết định trên thay thế trạng thái “chờ chốt” tương ứng trong snapshot bàn giao. Không sửa/xóa snapshot hay suy ra các luồng ghi đã tồn tại từ việc quyết định được phê duyệt.

## Contract R01

GET `/api/v1/admin/booking-policy`, chỉ ADMIN. Policy hiệu lực khi `active=true` và `effective_from <= now`, trong đó now lấy một lần từ Clock của ứng dụng. V4 đã giới hạn tối đa một policy active; R01 không tạo lịch sử/phiên bản mới hoặc chọn default khi thiếu policy.

Response 200 là DTO với `id,maxAdvanceDays,minNoticeHours,cancelDeadlineHours,maxFutureBookings,effectiveFrom`. effectiveFrom là thời điểm ISO-8601 UTC. Nếu không có row hiệu lực, trả envelope hiện có với HTTP/status 404 và `error.code=BOOKING_POLICY_NOT_FOUND`; 401/403 tiếp tục dùng contract bảo mật hiện hữu.

R01 chỉ SELECT trong transaction read-only. Không tạo hoặc sửa policy, không áp V7, không thay migrations V1–V6. Hành vi cập nhật policy và toàn bộ booking/membership lifecycle cần task triển khai tiếp theo dù quy tắc đã được chốt.
