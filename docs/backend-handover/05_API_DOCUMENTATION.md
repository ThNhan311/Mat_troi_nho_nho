# API hiện có

Nguồn: [controllers](../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/), [security](../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/SecurityConfig.java), [DTO](../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/). Phần bàn giao gốc phản ánh checkpoint 0ae542a; Task A có commit local 073e131, R01 là working tree sau commit đó. Phân biệt kết quả lịch sử với các lượt mới trong [báo cáo R01](evidence/R01_BOOKING_POLICY_READ.md). Không có phân trang.

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

Lỗi thường gặp: 400 `ERR_VALIDATION` cho input sai; 401 `ERR_UNAUTHORIZED` cho xác thực thất bại; 403 `ERR_FORBIDDEN` sai quyền; 404 `ERR_NOT_FOUND` nếu profile/plan/PT không có; 409 `ERR_CONFLICT` khi vi phạm dữ liệu; 500 `ERR_INTERNAL` cho lỗi không xử lý. Áp dụng tùy đường code, không hứa mọi endpoint phát sinh mọi mã. Envelope gồm `success:false`, `error:{code,message,details,correlationId}`, `timestamp`, `status`, `message`; có `X-Correlation-Id`. Ví dụ login/refresh dùng placeholder trong [cài đặt](03_LOCAL_SETUP_GUIDE.md). Các API ghi booking, policy, payment chỉ là backlog, chưa hoạt động.

## OpenAPI và giới hạn

[OpenAPI nháp](api/openapi.yaml) liệt kê các endpoint hiện có, role, DTO và tham số; cần review contract, ví dụ tổng hợp và kiểm tra bằng công cụ chuyên dụng trước khi công bố. Đặc tả và tài liệu này chưa có ví dụ request/response đầy đủ riêng cho từng endpoint và chưa phải contract hoàn chỉnh. Không dùng để tạo client production khi chưa review.
