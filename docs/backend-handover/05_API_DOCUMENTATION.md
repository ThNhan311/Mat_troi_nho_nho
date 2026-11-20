# API hiện có

Nguồn: [controllers](../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/), [security](../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/SecurityConfig.java), [DTO](../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/). Phần bàn giao gốc phản ánh checkpoint 0ae542a; Task A 073e131, R01 9ae0a50, R02 4d137d7 đã commit local. Booking create R03 là working tree sau R02; xem [báo cáo R03](evidence/R03_BOOKING_CREATE.md). Không có phân trang.

| Method, URL | Role/auth | Input | Response 200 | Service / bảng |
|---|---|---|---|---|
| POST `/api/v1/auth/login` | công khai | JSON `email`, `password` bắt buộc | `accessToken`, `refreshToken`, `role` | AuthService / users |
| POST `/api/v1/auth/refresh` | công khai | JSON `refreshToken` bắt buộc | như login | AuthService / users |
| GET `/api/v1/membership-plans` | MEMBER hoặc ADMIN, Bearer | không | mảng plan ACTIVE | MembershipPlanService / membership_plans |
| GET `/api/v1/membership-plans/{id}` | MEMBER hoặc ADMIN | UUID | plan ACTIVE | MembershipPlanService / membership_plans |
| GET `/api/v1/memberships/me` | MEMBER | không | mảng membership của chính user | MembershipService / users, members, memberships, plans |
| GET `/api/v1/trainers` | MEMBER | không | mảng PT có user ACTIVE | PersonalTrainerService / users, personal_trainers |
| GET `/api/v1/trainers/{ptId}` | MEMBER | UUID profile PT | PT ACTIVE | PersonalTrainerService / users, personal_trainers |
| GET `/api/v1/trainers/{ptId}/slots` hoặc `/availability` | MEMBER | `from`, `to` bắt buộc | mảng slot AVAILABLE trong tương lai | PersonalTrainerService / trainers, slots |
| GET `/api/v1/pt/slots` | PT | `from`, `to`; `status` tùy chọn | mảng slot của PT đăng nhập | AvailabilityService / users, trainers, slots |
| GET `/api/v1/bookings/me` | MEMBER | `from`, `to`; `status` tùy chọn | mảng booking của member đăng nhập | BookingQueryService / users, members, bookings |
| GET `/api/v1/pt/bookings` | PT | `from`, `to`; `status` tùy chọn | mảng booking của PT đăng nhập | BookingQueryService / users, trainers, bookings |
| GET `/api/v1/admin/booking-policy` | ADMIN, Bearer | không | policy hiệu lực, sáu trường DTO | BookingPolicyService / booking_policy |

## Member tạo booking auto-confirm R03

POST `/api/v1/bookings`, Bearer của MEMBER ACTIVE có profile; input bắt buộc `ptId`, `slotId` kiểu UUID theo schema, không dùng ID chữ minh họa trong Topic11. `memberId`/`status` từ client không được sử dụng; owner luôn là profile Member đăng nhập. Không có PENDING/REJECTED hoặc bước PT duyệt. Nguồn: Topic11 mục 1.5.5 UC-10, 5.3 và 7.2, [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md), [transaction/traceability R03](decisions/2026-11-20_R03_BOOKING_CREATE.md).

```json
{"ptId":"22222222-2222-4222-8222-222222222222","slotId":"33333333-3333-4333-8333-333333333333"}
```

HTTP 201 trả DTO Booking giống các GET hiện hữu: `id,memberId,ptId,slotId,startAt,endAt,status,cancelledBy,cancelReason,cancelledAt,completedAt`. Dùng tên `id` theo convention repository, thay vì `bookingId` trong ví dụ Topic11. UUID là ID thật do database/JPA tạo; không dùng UUID minh họa để chạy khi chưa có fixture. `status=CONFIRMED`, bốn trường cancellation/completion null; thời gian UTC, đúng snapshot slot đã khóa. Slot BOOKED cùng transaction và không còn trong danh sách MEMBER available; lịch Member/PT hiện có đọc được booking mới.

Membership phải có stored status ACTIVE và đang hiệu lực trên ngày hiện tại Việt Nam, đồng thời bao phủ toàn bộ session. DATE `start_date` bắt đầu lúc 00:00 Asia/Ho_Chi_Minh; `expiry_date` bao gồm hết ngày đó. Khoảng hiệu lực `[startDate 00:00, (expiryDate+1) 00:00)` được chuyển sang Instant để so sánh. Session `[start,end)` có thể kết thúc **đúng** ranh giới cuối, không được vượt dù một microsecond. Không đổi các DATE sang 00:00 UTC. Đây là kiểm tra lúc đặt; kiểm tra trước khi bắt đầu dịch vụ theo D01 chưa có lifecycle để triển khai.

PT phải ACTIVE và ptId khớp slot. Slot AVAILABLE, version không đổi trong lúc request chờ khóa, không có CONFIRMED, duration đúng 90 phút. Policy đọc từ thành phần R01 tại cùng mẫu Clock: active=true và effective_from<=now. Không có policy hiệu lực trả 404 BOOKING_POLICY_NOT_FOUND, không seed/fallback. Notice `start-now >= minNoticeHours`, advance `start-now <= maxAdvanceDays × 24 giờ`; equality hợp lệ, slot quá khứ bị từ chối kể cả notice=0. Bộ 14/2/4/5 chỉ là fixture/cấu hình, không hardcode vào booking.

Đếm booking của chính Member có status CONFIRMED và start_at>now; nếu số hiện có >= maxFutureBookings thì từ chối. Vì vậy 4 lịch với max=5 cho thêm một, 5 lịch bị chặn. CANCELLED/COMPLETED và CONFIRMED đã bắt đầu không được tính là tương lai. Không overlap booking CONFIRMED của Member hoặc PT, so khoảng `[start,end)` nên tiếp giáp được phép.

Transaction READ_COMMITTED, timeout 10 giây, khóa Member → membership hiện hành → PT → slot. Recheck accounts, membership, version/status, policy/count/overlap sau chờ khóa; flush BOOKED và insert CONFIRMED nguyên tử. Khóa Member bảo vệ count/overlap qua các slot/PT khác nhau; PT → slot phối hợp R02. Scalar version trước khi chờ khóa giúp từ chối PATCH đổi giờ cùng ID trong lúc request đang chờ. Payload hiện tại không có expectedVersion/time, nên không phát hiện UI đã cũ trước lần đọc đầu tiên của request; client cần refresh slot trước đặt.

| HTTP | Error code | Tình huống |
|---|---|---|
| 400 | ERR_VALIDATION | Thiếu/null/UUID/body sai |
| 401 | ERR_UNAUTHORIZED | Thiếu token hợp lệ hoặc account không ACTIVE khi xác thực |
| 403 | ERR_FORBIDDEN | ADMIN/PT hoặc Member không còn ACTIVE khi recheck sau chờ khóa |
| 404 | ERR_NOT_FOUND | Thiếu Member profile, PT không ACTIVE/không có, slot không có hoặc ptId/slotId không khớp |
| 404 | BOOKING_POLICY_NOT_FOUND | Không có policy hiệu lực, dùng nguyên contract R01 |
| 409 | ERR_SLOT_NO_LONGER_AVAILABLE | Slot BOOKED/DISABLED, có CONFIRMED hoặc version đổi trong lúc chờ |
| 409 | ERR_SLOT_INVALID_DURATION | Slot legacy không dài 90 phút |
| 409 | ERR_MEMBERSHIP_INACTIVE | Không có membership hiện hành ACTIVE hoặc chưa bắt đầu/đã hết hạn |
| 409 | ERR_MEMBERSHIP_NOT_COVERED | Không bao phủ toàn bộ session |
| 409 | ERR_BOOKING_NOTICE / ERR_BOOKING_ADVANCE | Vi phạm notice/advance |
| 409 | ERR_MAX_FUTURE_BOOKINGS | Đã đạt giới hạn lịch tương lai |
| 409 | ERR_BOOKING_OVERLAP | Chồng session CONFIRMED của Member/PT |
| 409 | ERR_CONFLICT | Chốt chặn constraint/concurrency/lock-timeout; không retry mù |

Mọi lỗi dùng envelope và correlation ID hiện hữu. Không triển khai cancel/complete, policy PUT, membership write hoặc Redis. DB constraints V4 là chốt chặn cuối, không thay thế giao thức khóa/đếm của ứng dụng.

## PT quản lý availability R02

Nguồn đã đọc: Topic11_FITCENTER.docx do người dùng cung cấp ngày 20/11/2026, mục 1.5.4 UC-13, 5.2 và 6.3; [lựa chọn triển khai theo V4](decisions/2026-11-20_R02_AVAILABILITY.md). Các endpoint ghi sau đã có code và HTTP tests; GET hiện hữu vẫn là `/api/v1/pt/slots`, không thêm GET `/api/v1/pt/availability` trùng chức năng.

| Method, URL | Input JSON | Thành công |
|---|---|---|
| POST `/api/v1/pt/availability` | bắt buộc startAt, endAt | 201, DTO slot AVAILABLE |
| PATCH `/api/v1/pt/availability/{slotId}` | ít nhất một trong startAt/endAt; trường thiếu giữ giá trị cũ | 200, DTO slot sau sửa hoặc slot thay thế |
| DELETE `/api/v1/pt/availability/{slotId}` | không body | 204, body rỗng; chuyển DISABLED, không xóa vật lý |

Chỉ tài khoản PT ACTIVE có profile. ptId lấy từ danh tính đăng nhập. DTO request chỉ có startAt/endAt; trường ngoài DTO như ptId/status không được sử dụng, không chuyển ownership hoặc trạng thái theo client. ADMIN/MEMBER 403; không token hoặc token của tài khoản đã SUSPENDED/DISABLED 401. Profile không tồn tại 404. Slot không có hoặc thuộc PT khác đều 404 `ERR_NOT_FOUND`.

```json
{"startAt":"2030-01-02T16:00:00+07:00","endAt":"2030-01-02T17:30:00+07:00"}
```

Đổi ngày ví dụ sang tương lai khi chạy thử. Input phải có offset, độ chính xác tối đa microsecond để không làm tròn khi ghi PostgreSQL. Start phải **sau** Clock.instant(), duration chính xác 90 phút theo thời lượng UTC. Bắt đầu bằng now bị 400; đây là yêu cầu slot mới nằm trong tương lai, khác các ranh giới policy D03. Response dùng UTC, gồm id, ptId, startAt, endAt, status giống DTO đọc. Không áp min notice/max advance hay yêu cầu tồn tại Booking Policy vào việc PT công bố slot.

Không chồng bất kỳ slot chưa DISABLED hoặc session CONFIRMED của cùng PT; so sánh khoảng `[start,end)` nên hai khoảng tiếp giáp được phép. Hai PT khác nhau được dùng cùng giờ. Vi phạm thời gian/body/UUID trả 400 `ERR_VALIDATION`; overlap hoặc trạng thái không cho sửa trả 409 `ERR_CONFLICT`, dùng envelope/correlation ID hiện có.

Slot BOOKED hoặc có booking CONFIRMED không được PATCH/DELETE dù status slot không nhất quán. PATCH chỉ áp dụng slot AVAILABLE chưa bắt đầu; không mở lại DISABLED/slot đã qua. Nếu chưa có booking nào, PATCH đổi giờ giữ ID. Nếu có lịch sử CANCELLED/COMPLETED và đổi giờ, transaction chuyển dòng cũ DISABLED, giữ nguyên booking/FK/thời gian lịch sử, tạo slot AVAILABLE mới và trả **ID mới**. Client phải dùng ID trong response; gọi PATCH dòng cũ sẽ bị 409. PATCH không đổi thời điểm không tạo slot thay thế. DELETE slot DISABLED không có CONFIRMED lặp lại trả 204.

DELETE loại slot khỏi GET danh sách khả dụng của MEMBER. GET PT không lọc status vẫn thấy DISABLED để xem lịch sử; `status=AVAILABLE` loại nó. Không ghi lại hoặc xóa booking. Transaction khóa theo PT, sau đó slot; constraint exclusion V4 tiếp tục bảo vệ overlap. Lock/optimistic/constraint conflict được chuyển thành 409 có kiểm soát. Xem giới hạn giao thức khóa cho booking write tương lai trong [quyết định R02](decisions/2026-11-20_R02_AVAILABILITY.md).

## Admin đọc Booking Policy

R01 áp dụng [quyết định D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md) trong phạm vi đọc policy: `active=true AND effective_from <= Clock.instant()`. Dấu bằng được chấp nhận. Không có row, chỉ có row inactive hoặc chỉ có active trong tương lai đều trả 404 `BOOKING_POLICY_NOT_FOUND`; không tự seed hoặc fallback 14/2/4/5. Repository chỉ có phương thức đọc và service chạy transaction read-only. GET không cập nhật updated_at hoặc trạng thái.

Ví dụ response 200 tổng hợp; các giá trị là dữ liệu DB, không phải default trong code:

```json
{
  "id": "11111111-1111-4111-8111-111111111111",
  "maxAdvanceDays": 14,
  "minNoticeHours": 2,
  "cancelDeadlineHours": 4,
  "maxFutureBookings": 5,
  "effectiveFrom": "2030-01-02T03:04:05.123456Z"
}
```

effectiveFrom là thời điểm UTC, ISO-8601; maxAdvanceDays là số ngày cấu hình, khi áp vào booking sẽ dùng thời lượng ngày × 24 giờ theo D06. GET chỉ trả dữ liệu, chưa áp giới hạn vào booking. Không token trả 401 `ERR_UNAUTHORIZED`; MEMBER/PT trả 403 `ERR_FORBIDDEN`, kể cả khi chưa có policy. Lỗi 404 dùng nguyên envelope hiện có: `success=false`, `status=404`, `error.code=BOOKING_POLICY_NOT_FOUND`, message, details, correlationId và timestamp; header X-Correlation-Id khớp body. Không có endpoint PUT policy hoặc booking write trong R01.

## Các API đọc hiện hữu

`from` và `to` là ISO-8601 có offset, `from < to`; lọc theo `startAt` trong `[from,to)`, tăng dần. Slot status: AVAILABLE, BOOKED, DISABLED. Booking status: CONFIRMED, CANCELLED, COMPLETED; chữ hoa đúng enum. Các endpoint `/me` và `/pt` resolve profile từ token, không nhận ID chủ sở hữu tùy ý.

DTO plan gồm `id,name,description,durationDays,price`; membership gồm `id,planId,planName,startDate,endDate,status`; PT gồm `id,fullName,bio,specialization,experienceSummary`; slot gồm `id,ptId,startAt,endAt,status`; booking gồm `id,memberId,ptId,slotId,startAt,endAt,status,cancelledBy,cancelReason,cancelledAt,completedAt`. Membership ACTIVE được tính trạng thái hiển thị theo ngày Việt Nam, không tự ghi thay đổi.

Ví dụ tổng hợp, URL encode dấu `+` thành `%2B`:

```http
GET /api/v1/pt/slots?from=2027-01-01T00:00:00Z&to=2027-02-01T00:00:00Z&status=AVAILABLE
Authorization: Bearer <access-token>
```

```json
[{"id":"11111111-1111-4111-8111-111111111111","ptId":"22222222-2222-4222-8222-222222222222","startAt":"2027-01-02T09:00:00Z","endAt":"2027-01-02T10:00:00Z","status":"AVAILABLE"}]
```

Lỗi thường gặp: 400 `ERR_VALIDATION` cho input sai; 401 `ERR_UNAUTHORIZED` cho xác thực thất bại; 403 `ERR_FORBIDDEN` sai quyền; 404 `ERR_NOT_FOUND` nếu profile/plan/PT không có; 409 `ERR_CONFLICT` khi vi phạm dữ liệu; 500 `ERR_INTERNAL` cho lỗi không xử lý. Áp dụng tùy đường code, không hứa mọi endpoint phát sinh mọi mã. Envelope gồm `success:false`, `error:{code,message,details,correlationId}`, `timestamp`, `status`, `message`; có `X-Correlation-Id`. Ví dụ login/refresh dùng placeholder trong [cài đặt](03_LOCAL_SETUP_GUIDE.md). Booking create R03 đã có; cancel/complete, policy write và payment vẫn chưa triển khai.

## OpenAPI và giới hạn

[OpenAPI nháp](api/openapi.yaml) liệt kê các endpoint hiện có, role, DTO và tham số; cần review contract, ví dụ tổng hợp và kiểm tra bằng công cụ chuyên dụng trước khi công bố. Đặc tả và tài liệu này chưa có ví dụ request/response đầy đủ riêng cho từng endpoint và chưa phải contract hoàn chỉnh. Không dùng để tạo client production khi chưa review.
