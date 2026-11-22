# M-01 — Admin tạo Membership Plan, 22/11/2026

Người dùng giao triển khai từ baseline local 1b1e323 trên feature/admin-membership-plan-create. Bốn tài liệu [khảo sát](../research/2026-11-22_CORE_MEMBERSHIP_PAYMENT_SURVEY.md), [V7](../research/2026-11-22_DATABASE_V7_REVIEW.md), [lát cắt](../research/2026-11-22_FIRST_SLICE_PLAN_CREATE.md) và [nguồn](../research/2026-11-22_SURVEY_SOURCES.json) được giữ nguyên như snapshot đề xuất; yêu cầu mới chỉ chốt M-01, không phê duyệt các quyết định Membership/Payment khác.

Nguồn Topic11 UC-21/§4.1/§5.2 và canonical V2. Không migration, không V7. [OpenAPI](../api/openapi.yaml), [báo cáo](../evidence/M01_PLAN_CREATE.md).

## Contract

POST /api/v1/admin/membership-plans, ADMIN ACTIVE. Principal email được resolve lại từ DB; role/status kiểm tại service trước INSERT. Security filter cũng kiểm account hiện tại: không token/account khóa 401; role sai 403; service recheck từ chối 403, user biến mất 401. Không nhận identity/status/owner/timestamps hoặc field khác ngoài bốn trường. Field lặp bị từ chối.

- name: JSON string không blank, tối đa100 Unicode code points như VARCHAR(100); không trim/chuyển case/ép unique. Hai tên giống nhau có thể tạo hai UUID.
- description: thiếu/null hoặc JSON string, TEXT không business cap mới; không U+0000 vì PostgreSQL TEXT không lưu được. Name cũng không U+0000.
- durationDays: bắt buộc, JSON integer int32 >0. String, boolean, array/object, float 1.0 và exponent 1e0 không được ép integer. Đơn vị ngày, không tháng×30.
- price: bắt buộc JSON number, BigDecimal đọc trực tiếp từ parser để không qua double/mất precision; >=0, tối đa10 chữ số phần nguyên và2 thập phân, đúng NUMERIC(12,2). Không rounding. 0 hợp lệ; quá scale bị400 dù rất nhỏ/vượt double precision. Chuỗi số không được ép number.

201 sau flush; UUID server, ACTIVE server. Body giống GET: id/name/description/durationDays/price, không status/timestamps. Validation400 ERR_VALIDATION và correlationId theo envelope hiện có. Constraint/concurrency conflict thực409 ERR_CONFLICT; không tự coi trùng tên là conflict. Không thêm idempotency key.

## Transaction và dữ liệu

Một transaction timeout10giây cho resolve/recheck actor và saveAndFlush plan. Không khóa Member, membership, PT, slot hoặc policy; không thêm thứ tự khóa ngược R03/R04. Không có các writer account mới trong M-01. Kiểm quyền là snapshot tại recheck, không hứa truy hồi một lệnh đã commit nếu actor bị khóa sau đó.

Chỉ INSERT membership_plans. Không tạo/sửa account/profile/membership/payment/booking/slot. Constraint thất bại hoặc lỗi sau INSERT trong transaction rollback toàn bộ; HTTP không lộ SQL. GET list/detail hiện hữu chỉ ACTIVE cho MEMBER/ADMIN được tái sử dụng, không thêm endpoint đọc hoặc quảng bá list INACTIVE.

## Admin Web gốc

Giữ Login/Home/navigation/theme và cấu trúc MembershipPage: header, cards/icon/typography, floating add, modal form. List lấy DTO thật, hiển thị UUID, ngày và giá có2 thập phân, không stats/mock. Menu Gói tập chỉ mô tả list ACTIVE+thêm. Edit/delete/status báo Chưa khả dụng, không mutation local.

ApiClient Admin giữ nguyên byte; token memory, bounded refresh, không replay write. Navigator theo epoch, modal useRootNavigator=false, mỗi response kiểm epoch+mounted. Logout/đổi account loại route/modal/response cũ. Form khóa lúc POST, chỉ201+DTO matching request mới success. Timeout/network/5xx/unexpected success status/DTO sai: khóa nút lưu của intent đó, GET đối chiếu và đóng modal; không tự retry hoặc tìm theo tên rồi khẳng định đúng gói. Tên không unique. Chỉ có UUID response đã nhận mới xác nhận identity.

Không tích hợp Member Membership UI; Member GET read-back chỉ là HTTP evidence. Không account creation, activation, renewal/payment, update/status/delete, Face/Workout.