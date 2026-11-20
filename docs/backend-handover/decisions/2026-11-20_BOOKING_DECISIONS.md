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

## Bổ sung nguồn và trạng thái khi tiếp nhận R02

R01 đã commit local `9ae0a50593a921ae6c629c93bd9f36f0b373ace9` sau khi đối chiếu evidence; các mô tả “chưa commit/chưa có Topic11” phía trên ghi trạng thái lúc nghiệm thu R01. Ngày 20/11/2026 người dùng cung cấp bản Topic11_FITCENTER.docx; đã đọc nội dung OOXML, đặc biệt UC-13 (1.5.4), auto-confirm (1.5.5), cancel/complete (1.5.6), API (5.2), duration (6.3) và locking minh họa (7.2). SHA256 bản được đọc: `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`. Không suy ra số trang từ OOXML hoặc sao chép tài liệu nguồn vào Git.

Nguồn xác nhận auto-confirm, session Core 90 phút, sửa/xóa slot chưa bị CONFIRMED ràng buộc, Member cancel cho rebook và PT cancel không tự reopen. D01–D07 vẫn là quyết định người dùng đã chốt; không tự thay đổi bằng ví dụ/pseudocode trong tài liệu. R02 chỉ triển khai availability write theo [quyết định triển khai](2026-11-20_R02_AVAILABILITY.md). D01, booking limits/eligibility/lifecycle, policy PUT/scheduling vẫn chưa triển khai. D07 không được coi là hoàn tất chỉ vì availability dùng DISABLED.

## Trạng thái khi triển khai R03

R02 đã commit local `4d137d703ab522e6f977d0e297f5a939a1011bcc`; R03 là working tree trên nhánh feature/backend-booking-create. Đã triển khai auto-confirm; phần D01 ACTIVE tại lúc đặt và bao phủ session theo DATE Việt Nam; D02 notice/advance/max future từ policy; D03 equality của notice/advance và membership end; D04 booking từ chối khi thiếu policy; D06 UTC/thời lượng ngày × 24 giờ. [Quyết định và traceability R03](2026-11-20_R03_BOOKING_CREATE.md) mô tả chi tiết và giới hạn. Không sửa quyết định nghiệp vụ đã chốt.

Chưa triển khai phần D01 kiểm tra lại trước bắt đầu dịch vụ; D05 PUT policy hiệu lực ngay; cancel deadline và D07 cancel/complete/completedAt. Scheduling/versioning vẫn hoãn. Những cột “trạng thái trong R01” và cập nhật R02 ở trên là checkpoint lịch sử, không dùng làm trạng thái hiện hành R03.
