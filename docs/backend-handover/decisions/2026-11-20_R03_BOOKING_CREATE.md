# R03 auto-confirm booking và giao thức khóa

Người dùng giao R03 ngày 20/11/2026 từ R02 commit `4d137d7`. Nguồn đã đọc: Topic11_FITCENTER.docx do người dùng cung cấp ngoài repository, SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`, đặc biệt 1.5.5 UC-10, 5.3 và 7.2; [D01–D07](2026-11-20_BOOKING_DECISIONS.md), [V2](../../../database/migrations/V2__membership_payment.sql), [V4](../../../database/migrations/V4__pt_booking.sql) và [R02](2026-11-20_R02_AVAILABILITY.md). Đọc nội dung OOXML, không dẫn số trang chưa kiểm chứng. Không thay source Topic11 bằng suy luận từ comment SQL.

## Contract và phạm vi

POST `/api/v1/bookings`, MEMBER ACTIVE có profile. Input `ptId,slotId` UUID; member_id lấy từ principal, không dùng memberId/status client. HTTP 201 trả [BookingResponse](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/booking/BookingResponse.java) hiện có với `id` theo API convention, status CONFIRMED và timestamp UTC; không thêm bookingId alias/PENDING/REJECTED hoặc PT approval. Body lỗi theo error envelope hiện hữu.

PT ACTIVE, ptId khớp slot; AVAILABLE, không có CONFIRMED, đúng 90 phút, không bị đổi version khi đang chờ. Slot DISABLED do DELETE/thay thế hoặc BOOKED đều ERR_SLOT_NO_LONGER_AVAILABLE. Slot legacy một giờ hợp schema nhưng không đủ Core 90 phút bị ERR_SLOT_INVALID_DURATION; không tự sửa dữ liệu cũ.

Policy được đọc qua thành phần R01 tại cùng Instant now của booking; overload getEffectivePolicyAt chia sẻ nguyên query/mapping/no-fallback, GET R01 vẫn lấy now từ Clock như trước. Thiếu/inactive/tương lai trả nguyên 404 BOOKING_POLICY_NOT_FOUND và rollback; đây là lỗi thiếu cấu hình theo contract R01, khác conflict nghiệp vụ 409. Không seed default. Notice/advance/count lấy từ DB, không hardcode 14/2/5; cancelDeadlineHours chỉ đọc trong DTO policy, chưa áp vì không có cancel ở R03.

## Membership DATE và các mốc

V2 dùng DATE, mỗi Member tối đa một dòng chưa CANCELLED. Status phải ACTIVE; ngày hiện tại Việt Nam nằm trong kỳ, không suy ra ACTIVE chỉ từ ngày hoặc kích hoạt lại trạng thái khác. Chuyển kỳ DATE thành `[start_date 00:00 Asia/Ho_Chi_Minh, (expiry_date+1) 00:00 Asia/Ho_Chi_Minh)` để so với UTC Instant. Không gán DATE thành UTC midnight. Session `[start,end)` phải nằm hoàn toàn trong kỳ; end đúng midnight sau expiry được phép vì endpoint cuối là exclusive. End vượt một microsecond bị từ chối. Now đúng ngày bắt đầu 00:00 Việt Nam được phép; now đúng midnight sau expiry là hết hạn.

Clock được sample sau khi có các khóa; policy hiệu lực và các phép tính dùng cùng now. `start-now >= minNoticeHours` và `start-now <= maxAdvanceDays × 24 giờ`, cả hai gồm equality. Luôn từ chối start<now kể cả minNotice=0. Future count là số CONFIRMED của Member có start_at>now; count hiện có >= maxFutureBookings thì từ chối. Các booking đã bắt đầu/CANCELLED/COMPLETED không tính. Kiểm overlap Member/PT trên khoảng `[start,end)`; tiếp giáp hợp lệ.

## Transaction và concurrency

Phương án được báo trước coding: khóa **Member → membership hiện hành → PT → slot** và insert/chuyển BOOKED nguyên tử. R03 dùng READ_COMMITTED khai báo rõ, timeout 10 giây để các query sau chờ khóa đọc được dữ liệu mới commit. Không dựa vào isolation mặc định hoặc retry mù.

1. Trong transaction, xác minh principal MEMBER ACTIVE, đọc scalar version của đúng cặp ptId/slotId. Không load slot entity trước khóa để tránh first-level cache giữ dữ liệu cũ.
2. Khóa Member bằng FOR NO KEY UPDATE. Mọi request của cùng Member, kể cả qua PT/slot khác nhau, tuần tự hóa trước count/overlap. Khóa membership hiện hành bằng PESSIMISTIC_READ để không bị UPDATE trạng thái/ngày giữa validation và commit.
3. Khóa PT bằng FOR NO KEY UPDATE, sau đó slot sở hữu bằng PESSIMISTIC_WRITE. Giữ đúng PT → slot của R02. NO KEY UPDATE ở parent Member/PT tương thích FK key-share của insert booking, tránh deadlock không cần thiết với transaction FK.
4. Recheck account bằng scalar queries mới sau chờ khóa, kiểm version/AVAILABLE/không CONFIRMED. Recheck membership eligibility, policy hiệu lực, duration/notice/advance/count/overlap bên trong transaction. Role/account trong token không được tin thay cho dữ liệu DB hiện tại.
5. Set BOOKED, flush slot; INSERT CONFIRMED với snapshot pt_id/slot_id/start_at/end_at của slot đã khóa. V4 composite FK, exclusion Member/PT và unique CONFIRMED theo slot là lớp bảo vệ cuối. Lỗi insert/constraint/lock rollback cả BOOKED/version và booking; conflict dự kiến 409 có mã ổn định, không lộ SQL/stack trace cho client.

Các race thực sự chờ khóa trước khi release, không chỉ submit tuần tự: hai Member/một slot; cùng Member/các slot khác PT tranh count=4; cùng Member/các slot chồng giờ; booking/PATCH và booking/DELETE ở cả hai thứ tự thắng. Khi booking thắng, R02 thấy BOOKED/CONFIRMED và trả 409. Khi PATCH thắng giữ cùng ID, scalar version trước chờ khác version sau khóa làm booking trả ERR_SLOT_NO_LONGER_AVAILABLE; không đặt nhầm giờ mới. DELETE thắng thì status/version cũng chặn booking. Khi PATCH thay thế vì lịch sử, ID cũ DISABLED không thể được đặt.

Payload Topic11 hiện chỉ có IDs, không có expectedVersion/thời gian từ client. Version guard chỉ phát hiện thay đổi kể từ lần đọc đầu tiên của request; không chứng minh UI chưa cũ trước lúc POST đến server. Muốn đổi contract optimistic concurrency ở phía client cần task riêng. Slot thay đổi trong lúc request chờ đã được bao phủ ở R03, không tự thêm field bắt buộc vào contract đã giao.

Writer booking/lifecycle tương lai phải phối hợp cùng khóa Member và PT/slot khi thay count/overlap; writer membership nên khóa Member trước membership. Raw SQL bỏ giao thức có thể vượt max count hoặc tạo trạng thái chéo V4 không cấm; R03 không tuyên bố DB tự enforce mọi invariant ứng dụng. Chốt chặn DB vẫn bảo đảm các FK/unique/exclusion đã có. Test rollback cố ý dùng writer SQL không giữ khóa Member để tạo race exclusion và chứng minh 409/rollback, không phải giao thức khuyến nghị cho production.

## Traceability và giới hạn

| Nguồn/quy tắc | Triển khai | Bằng chứng |
|---|---|---|
| Topic11 UC-10, FR-BKG-01..10, API 5.3 | [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/BookingCreateController.java), [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingCreateService.java), DTO hiện có | HTTP 201, owner/PT/slot/time, CONFIRMED, slot BOOKED và GET Member/PT/available |
| D01 khi đặt; V2 DATE | [validator](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingEligibilityValidator.java), membership read lock | Unit và HTTP inactive/chưa bắt đầu/không phủ hết session/ranh giới ngày Việt Nam |
| D02/D03/D06; FR-POL-01..05 | R01 policy component + validator/count query | Notice/advance ±1 microsecond/equality, 14×24 giờ, count 4/5 và policy tùy chỉnh |
| D04 | R01 getEffectivePolicyAt, không default | HTTP absent/inactive/future 404; slot/booking không đổi |
| Topic11 BR-BKG-01..06, AC-BKG-01..03; V4 | Member/PT/slot locks, overlap/count queries, FK/exclusion/unique | Hai Member/một slot; cùng Member/các slot; tiếp giáp/overlap Member/PT |
| Topic11 UC-13 + UC-10; R02 version/locks | PT → slot, scalar version guard | Race với PATCH/DELETE, cả booking thắng và availability thắng |
| NFR-REL-01 và atomic confirmation | Transaction READ_COMMITTED, no retry, error handler 409 | Exclusion conflict sau flush BOOKED rollback; không slot BOOKED thiếu booking |

Tests nằm trong [HTTP harness](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) nhóm BookingCreateCases và [validator unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingEligibilityValidatorTest.java); số thực chạy/source hashes ở [evidence R03](../evidence/R03_BOOKING_CREATE.md).

Không có blocker schema cần migration trong phạm vi R03. Không sửa V1–V6, không áp V7, không Redis/dependency mới. Chưa có cancel/complete, policy PUT, membership write hoặc kiểm tra lại eligibility trước bắt đầu dịch vụ. Scheduling/versioning tiếp tục hoãn. D01–D07 được triển khai từng phần như sổ quyết định, không tuyên bố lifecycle đã hoàn tất.
