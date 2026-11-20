# Contract Admin Booking Policy write

Nguồn: task người dùng ngày 20/11/2026; Topic11 UC-22 (bảng use cases), mục 6.5 Admin Booking Policy Form; [D01–D07](2026-11-20_BOOKING_DECISIONS.md), [V4](../../../database/migrations/V4__pt_booking.sql), R01/R03/R04. Topic11 ngoài repo đã đọc OOXML, SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`; không suy ra số trang. Mục 6.5 có UI Effective From và nói không hồi tố invalid booking CONFIRMED; D05/người dùng giới hạn giai đoạn này chỉ có hiệu lực ngay, không scheduling/versioning đầy đủ.

R04 đã đóng local `8cb95e23a9fbf357ce452bdb1bdeecaa4db824c0`; nhánh feature/backend-booking-policy-write được tạo từ đó sau kiểm tra tên chưa tồn tại. Phương án dưới đây đã báo trước coding. Task này chưa stage/commit, không push/merge.

## Contract và lưu trữ

PUT `/api/v1/admin/booking-policy`, chỉ ADMIN ACTIVE. JSON đúng bốn fields số nguyên: maxAdvanceDays>=1, minNoticeHours>=0, cancelDeadlineHours>=0, maxFutureBookings>=1. Miền trên là INTEGER signed 32-bit của V4; không thêm business cap hoặc quan hệ giữa fields. Thiếu/null/sai kiểu (kể cả số dạng string/decimal) và field ngoài contract, gồm effectiveFrom, trả 400 ERR_VALIDATION. Không nhận thời điểm tương lai/hồi tố từ client. Server đặt effectiveFrom từ Clock sau khi chờ khóa, truncate microseconds theo độ chính xác PostgreSQL. Không seed/default 14/2/4/5 trong logic.

200 DTO R01 sáu fields id,maxAdvanceDays,minNoticeHours,cancelDeadlineHours,maxFutureBookings,effectiveFrom UTC. Không token/account không ACTIVE lúc auth: 401 ERR_UNAUTHORIZED; sai role hoặc account không còn ACTIVE sau chờ khóa: 403 ERR_FORBIDDEN. Constraint/lock-timeout/concurrency conflict dùng 409 ERR_CONFLICT và envelope/correlation hiện hữu; không SQL/stack trace hoặc retry mù.

**Lựa chọn triển khai:** UPDATE toàn bộ cấu hình của row active tại chỗ, giữ ID, kể cả row active hiện có effective_from tương lai; PUT biến nó thành hiệu lực ngay. Nếu không có active (bảng trống hoặc chỉ có inactive), INSERT active UUID mới. Bản inactive sẵn có không sửa/xóa. Ghi updated_by từ principal ADMIN; updated_at theo trigger V4. Một SQL statement ghi trọn bộ fields/effective_from/actor trong transaction. Không tạo lịch sử mỗi lần sửa active, không lưu snapshot policy theo booking, không gọi đây là versioning đầy đủ. Schema V4 cho phép UPDATE tại chỗ; không sửa migration.

## Transaction, đồng thời và tác động

READ_COMMITTED, timeout 10 giây. PostgreSQL transaction advisory lock hai khóa `(20261120,22)`, namespace của FitCenter booking policy: PUT lấy exclusive trước khi chọn row/Clock/write, nên cả bảng ban đầu trống cũng được tuần tự hóa. Hai PUT hợp lệ có thể cùng thành công; **last-write-wins theo thứ tự lấy khóa/commit**, không hứa thứ tự request đến và không yêu cầu version/If-Match. Unique partial index V4 vẫn là chốt chặn tối đa một active; writer ngoài giao thức không được bảo đảm last-write-wins.

GET và policy snapshot R03/R04 lấy shared lock cùng key, rồi mới lấy Clock và SELECT trọn một DTO; không thấy trạng thái nửa cập nhật. Nếu reader lấy khóa trước thì dùng snapshot cũ và writer chờ reader transaction kết thúc; writer lấy trước thì reader chờ và lấy now/policy mới sau commit. R03 giữ Member→membership→PT→slot→policy shared; R04 Member cancel giữ Member→PT→slot→booking→policy shared. PUT chỉ lấy policy exclusive và ghi policy, không khóa Member/membership/PT/slot/booking; không tạo chiều khóa ngược. Read repository/entity R01 vẫn read-only/immutable; JDBC write riêng dùng cùng transaction manager/datasource.

Giới hạn mới dùng cho create tiếp theo. Giảm maxFutureBookings không tự hủy/sửa booking cũ, chỉ chặn thêm nếu count đã đạt/vượt giới hạn mới. PUT không update bookings/slots. R04 Member cancel đọc **policy hiệu lực lúc yêu cầu hủy**, không snapshot lúc đặt: đổi cancelDeadlineHours có thể cho phép hoặc từ chối yêu cầu hủy sau cập nhật đối với booking đã tồn tại. Đây là hành vi R04/người dùng yêu cầu giữ, khác với việc hồi tố đổi trạng thái/time/owner của booking. Topic11 6.5 không yêu cầu snapshot deadline lúc đặt; không đổi hành vi đã chốt.

D05 immediate update được triển khai trong task này; D01 service-start eligibility recheck vẫn chưa triển khai. Completion không thay thế service-start check. Không làm membership/payment/Face, không sửa V1–V6 hoặc áp V7.

## Traceability

| Nguồn/quy tắc | Code | Bằng chứng |
|---|---|---|
| UC-22, Topic11 6.5; bốn giới hạn | BookingPolicyWriteRequest, AdminBookingPolicyController | HTTP thiếu/null/kiểu/miền INTEGER, min equality, int max, không tự thêm quan hệ fields |
| D05; server quyết định effectiveFrom | BookingPolicyWriteService, Clock sau exclusive lock | HTTP tạo đầu tiên/update/get, client time bị 400, giữ request chờ rồi dịch Clock, precision microseconds |
| V4 unique active; empty-table concurrency | BookingPolicyLock, BookingPolicyWriteRepository | Hai Admin/Bcrypt khác nhau, bốn races empty/existing/đảo actor; cùng ID, đúng một active, last writer đủ bộ values/updated_by |
| ADMIN ACTIVE/principal | SecurityConfig, BookingPolicyWriteService recheck | HTTP 401/403, role/account locked; suspend khi đang chờ khóa trả 403 không write |
| Consistent snapshot với R03/R04 | BookingPolicyService shared lock; R03 lockAndGetTime; R04 getEffectiveSnapshot | GET/create/cancel cùng chờ PUT commit, đọc cấu hình/Clock mới, không nửa cập nhật; rollback first/update giữ cấu hình cũ |
| Không hồi tố sửa state booking; R04 cancellation semantics | PUT chỉ ghi booking_policy | Giảm count limit không đổi full booking/slot snapshots; create bị chặn; booking cũ áp cancellation deadline sau PUT, equality được phép |
| D01 service-start recheck | Chưa triển khai | Không dùng completion hoặc policy PUT để tuyên bố có service-start check |

Code: [write service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyWriteService.java), [write repository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyWriteRepository.java), [lock](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/BookingPolicyLock.java), [read service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingPolicyService.java), [HTTP/DB](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java). Kết quả và hashes: [báo cáo](../evidence/BOOKING_POLICY_WRITE.md).
