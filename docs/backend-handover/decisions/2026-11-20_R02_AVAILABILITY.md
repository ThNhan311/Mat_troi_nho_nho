# Quyết định triển khai availability R02

Ngày 20/11/2026, người dùng giao PT availability POST/PATCH/DELETE từ R01 commit `9ae0a50`. Nguồn đã đọc là Topic11_FITCENTER.docx đính kèm ngoài repository, SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`: UC-13 tại 1.5.4, API 5.2, session duration 6.3, booking lock minh họa 7.2. Nội dung được đọc từ OOXML; không dẫn số trang chưa render/kiểm chứng. [D01–D07](2026-11-20_BOOKING_DECISIONS.md) và chỉ đạo trực tiếp của người dùng có hiệu lực; không tự thêm yêu cầu ngoài phạm vi đã giao.

## Yêu cầu nghiệp vụ đã xác định

Chỉ PT ACTIVE có profile, quản lý slot của chính mình qua danh tính xác thực. Session Core dài 90 phút; slot mới trong tương lai; không chồng slot khả dụng hoặc session CONFIRMED cùng PT; tiếp giáp cho phép. Không sửa/xóa BOOKED hoặc slot có CONFIRMED. Bảo toàn lịch sử booking và FK. Không mở lại slot đã qua; PT cancel không tự reopen theo D07. Không triển khai booking write, policy PUT hoặc lifecycle.

## Lựa chọn dựa trên schema hiện tại

[V4](../../../database/migrations/V4__pt_booking.sql) có `fk_booking_slot(slot_id,pt_id,start_at,end_at)` tham chiếu identity ghép của slot, không ON DELETE/UPDATE CASCADE. Cả CANCELLED/COMPLETED cũng tham chiếu FK này. `ex_slot_pt_no_overlap` áp mọi slot chưa DISABLED với khoảng PostgreSQL `[start,end)`. Schema chưa có constraint duration 90 phút hoặc ràng buộc chéo CONFIRMED ⇒ BOOKED.

- **DELETE:** luôn chuyển DISABLED, 204 body rỗng; không xóa vật lý, kể cả slot chưa có lịch sử. Đây là lựa chọn triển khai thống nhất, đã báo trước coding, để giữ lịch sử/FK. Business chỉ yêu cầu loại slot chưa booked khỏi khả năng đặt; không bắt buộc hard delete. Lặp DELETE DISABLED không có CONFIRMED là no-op 204. GET PT mọi trạng thái vẫn thấy row; GET MEMBER khả dụng loại nó.
- **PATCH:** ít nhất một time field, bỏ trường thì giữ giá trị cũ. Chỉ sửa AVAILABLE chưa bắt đầu, không re-enable DISABLED. Thời điểm không đổi là no-op. Khi đổi thời gian và chưa có booking: UPDATE giữ ID. Khi có lịch sử không CONFIRMED: DISABLED dòng cũ, flush, insert slot AVAILABLE mới trong cùng transaction, trả ID mới. Không cập nhật timestamp/slot_id của booking lịch sử; không cascade, không xóa booking. Lỗi ở bất kỳ bước nào rollback cả transaction. Lựa chọn thay thế tránh đặt thêm một quyết định nghiệp vụ “cấm mọi slot có lịch sử” mà vẫn giữ FK hiện tại.
- **Precision/identity:** nhận timestamp có offset, tối đa microsecond; không âm thầm làm tròn precision cao hơn PostgreSQL. UTC response. DTO không dùng ptId/status client. 400 cho thời gian/body/UUID sai; 404 cho không có/không sở hữu slot; 409 ERR_CONFLICT cho booked/overlap/không thể chỉnh hoặc concurrent conflict. Đây là contract triển khai, không thêm trạng thái nghiệp vụ.
- **Policy:** không dùng policy 14/2/4/5 để giới hạn việc PT công bố availability. Các giới hạn này dành cho Member đặt booking; chưa có booking write.

## Transaction và giao thức khóa

Mỗi request ghi dùng transaction, timeout 10 giây. Resolve ACTIVE PT từ principal email, khóa row personal_trainers bằng PostgreSQL `FOR NO KEY UPDATE`, sau đó PATCH/DELETE khóa slot sở hữu bằng JPA PESSIMISTIC_WRITE. Khóa PT tuần tự hóa create khi chưa có row slot để khóa, đồng thời phối hợp create/update/disable cùng PT. NO KEY UPDATE vẫn tương thích FK key-share của một transaction booking, tránh cycle giữa khóa parent PT và slot. Sau khi giữ khóa slot phải kiểm tra lại BOOKED hoặc booking CONFIRMED trước thay đổi. Khi đổi slot lịch sử, flush DISABLED trước insert để exclusion không tính interval cũ.

Query overlap kiểm cả slots chưa DISABLED và bookings CONFIRMED, dùng `existing.start < requested.end AND existing.end > requested.start`. Constraint exclusion V4 là chốt chặn thêm cho các writer khác. DataIntegrityViolation, optimistic/pessimistic/lock/query-timeout failures dùng error envelope 409, không lộ SQL hoặc stack trace cho client.

Booking write tương lai **phải** giữ slot lock trong cùng transaction, kiểm tra lại AVAILABLE và mọi điều kiện sau khóa trước insert CONFIRMED. Khi cần cả PT và slot, cùng thứ tự PT → slot. R02 đã test competing SQL transaction có slot lock/insert CONFIRMED trước commit; HTTP PATCH/DELETE chờ rồi nhận 409. Chưa có booking endpoint để tuyên bố race giữa hai API nghiệp vụ đã được kiểm thử. Writer SQL tùy ý bỏ giao thức và tự chèn CONFIRMED vào slot DISABLED không bị V4 cấm hoàn toàn; R02 không sửa schema/trigger để bổ sung invariant đó. Đây là giới hạn tích hợp phải giữ khi làm R03, không phải bảo đảm cho mọi writer ngoài ứng dụng.

Không có quyết định nghiệp vụ còn thiếu làm chặn phạm vi R02 đã giao. Mọi trạng thái read/lifecycle ngoài các lựa chọn trên giữ nguyên; không áp V7 hoặc chỉnh migration đã áp dụng.
