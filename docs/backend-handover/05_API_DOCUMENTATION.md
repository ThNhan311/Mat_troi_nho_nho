Cập nhật rehearsal22/11: PT activation đã đạt HTTP/PostgreSQL/mail sink/UI thật trên DB riêng với V8 ở location riêng. Default vẫn503; chỉ profile test đã guard được bật. Không đổi API/contract OTP, không áp V7. [Evidence](evidence/PT_ACTIVATION_POSTGRES.md), [schema/order](decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md). Các thông tin chờ schema bên dưới là snapshot trước quyền mới, còn áp cho release production.

Cập nhật Account/PT activation22/11: Admin GET/POST `/api/v1/admin/members` và `/api/v1/admin/personal-trainers` chạy trên V1–V6, tạo DISABLED + profile nguyên tử, không membership. Ba POST `/api/v1/auth/pt-activation/{request-otp|verify-otp|password}` đã chuẩn bị nhưng **mặc định503**, chưa được bật trước thống nhất schema. [Contract/khóa/gate](decisions/2026-11-22_ACCOUNT_PT_ACTIVATION.md), [evidence](evidence/ACCOUNT_PT_ACTIVATION.md), [OpenAPI](api/openapi.yaml). Mọi đoạn “chưa account” phía dưới là checkpoint lịch sử, không phủ định cập nhật này; chưa nghiệm thu activation PostgreSQL/email production.
# API hiện có

Cập nhật M-01 (22/11/2026), baseline local 1b1e323, working tree feature/admin-membership-plan-create: POST `/api/v1/admin/membership-plans` cho ADMIN ACTIVE, HTTP201 trả DTO plan hiện có. Tên không unique, đơn vị ngày, giá0 hợp lệ; request strict chỉ name/description/durationDays/price, không rounding NUMERIC(12,2). Hai GET active list/detail được tái sử dụng. [Contract M-01](decisions/2026-11-22_M01_PLAN_CREATE.md), [evidence](evidence/M01_PLAN_CREATE.md), [OpenAPI](api/openapi.yaml).

Web Member/PT Booking và Admin Policy đã tích hợp trên màn hình gốc tại baseline; M-01 thêm list ACTIVE và tạo plan trên Admin MembershipPage. Các đoạn checkpoint phía dưới giữ nguyên lịch sử, không mô tả đầy đủ hiện trạng. D01 là snapshot, không start marker/hard gate dịch vụ vật lý. Checkpoint M-01: chưa account creation/activation/renewal/payment write, plan update/status/delete hoặc Member Membership UI.
Cập nhật D01: policy write đã commit local `63fe394`. Working tree feature/backend-service-eligibility thêm GET kiểm tra điều kiện hiện tại cho PT sở hữu booking, phương án A; không lưu dấu bắt đầu, không đổi completion. Frontend chưa tích hợp nên chưa hoàn tất luồng chặn dịch vụ end-to-end. Các trạng thái D01 “chưa triển khai” ở checkpoint phía dưới được thay bằng cập nhật này. [Contract D01](decisions/2026-11-20_SERVICE_ELIGIBILITY.md), [báo cáo](evidence/SERVICE_ELIGIBILITY.md).

Cập nhật Policy write: R04 đã commit local `8cb95e2`. Working tree feature/backend-booking-policy-write thêm PUT Admin Booking Policy hiệu lực ngay theo D05, xem [quyết định](decisions/2026-11-20_BOOKING_POLICY_WRITE.md) và [báo cáo](evidence/BOOKING_POLICY_WRITE.md). Các cập nhật R01–R04 phía dưới là checkpoint theo task; trạng thái hiện tại gồm GET/PUT policy, booking create và ba lifecycle endpoints. D01 service-start check vẫn chưa triển khai.

Cập nhật R04: R03 đã commit local `394a21f`. Working tree feature/backend-booking-lifecycle triển khai Member cancel, PT cancel và PT complete. Người dùng chốt PT chỉ được hủy khi `now < startAt`; lấy Clock sau khi chờ khóa. Xem [contract/quyết định R04](decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md), [báo cáo R04](evidence/R04_BOOKING_LIFECYCLE.md). Các giới hạn “chưa cancel/complete” ở checkpoint R03 bên dưới là lịch sử; D01 service-start check vẫn chưa triển khai.

Nguồn: [controllers](../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/), [security](../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/SecurityConfig.java), [DTO](../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/). Phần bàn giao gốc phản ánh checkpoint 0ae542a; Task A 073e131, R01 9ae0a50, R02 4d137d7 và R03 394a21f đã commit local. R04 working tree có ba endpoint lifecycle; xem [báo cáo R04](evidence/R04_BOOKING_LIFECYCLE.md). Không có phân trang.

| Method, URL | Role/auth | Input | Response thành công | Service / bảng |
|---|---|---|---|---|
| POST `/api/v1/auth/login` | công khai | JSON `email`, `password` bắt buộc | `accessToken`, `refreshToken`, `role` | AuthService / users |
| POST `/api/v1/auth/refresh` | công khai | JSON `refreshToken` bắt buộc | như login | AuthService / users |
| POST `/api/v1/admin/membership-plans` | ADMIN ACTIVE | JSON name/description?/durationDays/price | 201 plan DTO, UUID server; ACTIVE trong DB | MembershipPlanCreateService / membership_plans |
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

## D01 — kiểm tra service eligibility hiện tại

GET `/api/v1/pt/bookings/{id}/service-eligibility`, Bearer của PT ACTIVE có profile sở hữu booking; UUID path. Không dùng memberId/ptId từ query để xác định ownership. PT khác/thiếu booking/profile trả 404 ERR_NOT_FOUND; MEMBER/ADMIN 403 ERR_FORBIDDEN, không token/account bị khóa khi auth 401 ERR_UNAUTHORIZED, UUID sai 400 ERR_VALIDATION. Dùng error envelope/correlation hiện có.

PT được phép truy cập nhận 200 với đúng ba fields, kể cả khi không đủ điều kiện:

```json
{"eligible":false,"checkedAt":"2030-01-02T03:04:05.123456Z","reasonCodes":["MEMBERSHIP_INACTIVE"]}
```

`eligible=true` khi và chỉ khi reasonCodes rỗng. checkedAt lấy một lần từ server Clock trong transaction, ISO-8601 UTC. `Cache-Control: no-store`, không cache server. Không trả ID/name/profile/account/membership details hoặc dữ liệu cá nhân vượt mức cần đánh giá.

| Reason code | Điều kiện từ chối |
|---|---|
| BOOKING_NOT_CONFIRMED | CANCELLED hoặc COMPLETED |
| SESSION_NOT_STARTED | now < startAt |
| SESSION_ENDED | now >= endAt |
| MEMBER_ACCOUNT_INACTIVE | Account Member không ACTIVE (hoặc role không còn MEMBER) |
| MEMBERSHIP_INACTIVE | Thiếu membership hiện hành chưa CANCELLED, stored status khác ACTIVE, dates thiếu hoặc không hiệu lực hiện tại |
| MEMBERSHIP_NOT_COVERED | Membership hiện tại hợp lệ nhưng không bao phủ toàn session |

Thu thập các lý do độc lập theo thứ tự bảng, không trùng; nhóm membership kiểm coverage sau khi xác nhận ACTIVE/hiệu lực hiện tại như R03. Cửa sổ `[startAt,endAt)`: đúng start được phép, đúng end bị từ chối. Tái dùng riêng membership DATE Asia/Ho_Chi_Minh, expiry inclusive; session end đúng midnight sau expiry hợp lệ. Không tái áp notice/advance/max-future hoặc cancellation policy, không yêu cầu tồn tại policy.

Read-only REPEATABLE_READ, timeout 10 giây: SELECT actor đầu tiên thiết lập snapshot, Clock lấy trong transaction, mọi read booking/account/membership cùng MVCC snapshot. Query membership riêng không có khóa PESSIMISTIC_READ của R03; không khóa hàng/policy, không mutation booking/slot/membership/completion. Writer commit trong lúc GET chạy không làm các reads trộn dữ liệu; GET mới thấy snapshot mới. Kết quả là đánh giá tại checkedAt trên snapshot đó, không phải quyền sử dụng lâu dài hoặc bảo đảm dữ liệu không đổi sau response.

D01 đã có API kiểm tra phía Backend; Frontend chưa tích hợp thì không tuyên bố luồng chặn dịch vụ end-to-end hoàn tất. Không có startedAt/startedBy, IN_PROGRESS hoặc phương án B; complete vẫn theo R04, không bắt buộc gọi GET trước.

## Booking lifecycle R04 — phần đã triển khai

| Method, URL | Quyền và input | Thành công |
|---|---|---|
| POST `/api/v1/bookings/{id}/cancel` | MEMBER ACTIVE sở hữu booking; không cần body/membership ACTIVE | 200 BookingResponse, CANCELLED |
| POST `/api/v1/pt/bookings/{id}/cancel` | PT ACTIVE của booking; JSON `reason` bắt buộc | 200 BookingResponse, CANCELLED |
| POST `/api/v1/pt/bookings/{id}/complete` | PT ACTIVE của booking; không cần body | 200 BookingResponse, COMPLETED |

`id` là UUID Booking. Owner/actor lấy từ principal/profile, không tin actor trong client body. Response dùng nguyên 11 trường DTO của GET, ISO-8601 UTC. Member cancel lưu cancelledBy=MEMBER, cancelReason=null, cancelledAt=Clock.now, completedAt=null. Complete lưu completedAt=Clock.now, các trường hủy null. Không sửa identity/startAt/endAt hoặc xóa lịch sử.

Chỉ CONFIRMED được chuyển. CANCELLED/COMPLETED, kể cả request lặp, trả **409 ERR_BOOKING_NOT_CONFIRMED**, không sửa lại metadata hoặc slot. Kiểm trạng thái sau khóa và trước policy/deadline; request hủy cũ không tác động slot đã được Member khác đặt lại.

Member cancel lấy policy R01 đang hiệu lực tại now; thiếu/inactive/tương lai trả 404 BOOKING_POLICY_NOT_FOUND và không mutation. Điều kiện `startAt-now >= cancelDeadlineHours`, equality được phép, không hardcode 4 giờ. Slot có startAt>now trở lại AVAILABLE cho Member khác đặt; tại startAt với deadline=0 chuyển DISABLED để không mở lại slot đã qua/đang bắt đầu. Membership EXPIRED/SUSPENDED/PENDING_ACTIVATION/CANCELLED không chặn cancellation; account xác thực vẫn phải ACTIVE. Không tái dùng create eligibility validator.

Complete chỉ khi `now >= endAt`, equality được phép; slot DISABLED và không tự reopen. Không yêu cầu policy/membership ACTIVE cho completion. Đây là ghi hoàn thành sau session, **không thay thế D01 kiểm tra trước bắt đầu dịch vụ**. API D01 phương án A ở trên không ghi marker và không thay điều kiện complete.

Các mã lỗi: 400 ERR_VALIDATION cho UUID/input/reason sai; 401 ERR_UNAUTHORIZED khi không có token hợp lệ/account đã khóa lúc auth; 403 ERR_FORBIDDEN sai role hoặc account không ACTIVE khi recheck; 404 ERR_NOT_FOUND cho profile/booking không có hoặc không sở hữu. Business 409 gồm ERR_BOOKING_NOT_CONFIRMED, ERR_CANCELLATION_DEADLINE, ERR_PT_CANCELLATION_WINDOW_CLOSED, ERR_BOOKING_NOT_ENDED, ERR_BOOKING_SLOT_CONFLICT; constraint/concurrency 409 ERR_CONFLICT. Dùng envelope/correlation hiện hữu, không SQL/stack trace, không retry mù.

Transaction READ_COMMITTED khóa Member → PT → slot → booking, không đọc/khóa membership. Task policy write bổ sung shared policy lock cuối chuỗi cho Member cancel, rồi mới lấy Clock/policy; PT cancel/complete không đọc policy. Projection IDs ban đầu không cache Booking entity; re-read/recheck sau khóa, chặn CONFIRMED khác trước đổi slot. Flush booking terminal trước, rồi slot; lỗi ở bất kỳ bước nào rollback cả metadata và slot. Cancel đồng thời rebook có thể khiến POST booking đang chờ bị version guard từ chối; client refresh rồi gửi request mới, server không retry tự động. R02 PATCH sau Member cancel có lịch sử vẫn có thể trả slot thay thế ID mới, giữ FK của booking cũ.

PT cancel nhận JSON `{"reason":"Lịch PT thay đổi — dữ liệu tổng hợp"}`. Reason không thiếu/null/rỗng/chỉ whitespace (gồm Unicode whitespace), tối đa 500 Unicode code points theo VARCHAR(500), giữ nguyên văn. Chỉ PT ACTIVE sở hữu booking CONFIRMED và **now < startAt**. Đúng bằng hoặc sau startAt trả **409 ERR_PT_CANCELLATION_WINDOW_CLOSED**. Clock lấy sau khi có đủ khóa và recheck, không dùng thời điểm request đến. Thành công lưu CANCELLED, cancelledBy=PT, cancelledAt=now UTC, cancelReason, completedAt=null; slot DISABLED, không tự reopen. Không yêu cầu policy hoặc membership của Member ACTIVE. Quy tắc thời gian này do người dùng chốt sau khi xác nhận Topic11 chưa nói rõ, xem quyết định R04.

## Member tạo booking auto-confirm R03

POST `/api/v1/bookings`, Bearer của MEMBER ACTIVE có profile; input bắt buộc `ptId`, `slotId` kiểu UUID theo schema, không dùng ID chữ minh họa trong Topic11. `memberId`/`status` từ client không được sử dụng; owner luôn là profile Member đăng nhập. Không có PENDING/REJECTED hoặc bước PT duyệt. Nguồn: Topic11 mục 1.5.5 UC-10, 5.3 và 7.2, [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md), [transaction/traceability R03](decisions/2026-11-20_R03_BOOKING_CREATE.md).

```json
{"ptId":"22222222-2222-4222-8222-222222222222","slotId":"33333333-3333-4333-8333-333333333333"}
```

HTTP 201 trả DTO Booking giống các GET hiện hữu: `id,memberId,ptId,slotId,startAt,endAt,status,cancelledBy,cancelReason,cancelledAt,completedAt`. Dùng tên `id` theo convention repository, thay vì `bookingId` trong ví dụ Topic11. UUID là ID thật do database/JPA tạo; không dùng UUID minh họa để chạy khi chưa có fixture. `status=CONFIRMED`, bốn trường cancellation/completion null; thời gian UTC, đúng snapshot slot đã khóa. Slot BOOKED cùng transaction và không còn trong danh sách MEMBER available; lịch Member/PT hiện có đọc được booking mới.

Membership phải có stored status ACTIVE và đang hiệu lực trên ngày hiện tại Việt Nam, đồng thời bao phủ toàn bộ session. DATE `start_date` bắt đầu lúc 00:00 Asia/Ho_Chi_Minh; `expiry_date` bao gồm hết ngày đó. Khoảng hiệu lực `[startDate 00:00, (expiryDate+1) 00:00)` được chuyển sang Instant để so sánh. Session `[start,end)` có thể kết thúc **đúng** ranh giới cuối, không được vượt dù một microsecond. Không đổi các DATE sang 00:00 UTC. Đây là kiểm tra lúc đặt; kiểm tra trước khi bắt đầu dịch vụ theo D01 vẫn chưa triển khai.

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

Mọi lỗi dùng envelope và correlation ID hiện hữu. R03 không gồm lifecycle; R04 thêm Member/PT cancel và PT complete theo mục riêng ở trên; task policy write thêm PUT có hiệu lực ngay. Membership write và Redis vẫn ngoài phạm vi. DB constraints V4 là chốt chặn cuối, không thay thế giao thức khóa/đếm của ứng dụng.

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

## Admin cập nhật Booking Policy có hiệu lực ngay

PUT `/api/v1/admin/booking-policy`, chỉ ADMIN ACTIVE, body đúng bốn JSON integer fields; thiếu/null/sai kiểu, số dạng string/decimal hoặc field ngoài contract đều trả 400 ERR_VALIDATION. Không nhận effectiveFrom, lịch tương lai/hồi tố, updatedBy hoặc version từ client. Giá trị nằm trong INTEGER signed 32-bit của V4, không thêm quan hệ giữa fields hoặc business cap.

```json
{"maxAdvanceDays":14,"minNoticeHours":2,"cancelDeadlineHours":4,"maxFutureBookings":5}
```

Ví dụ tổng hợp, không phải fallback. maxAdvanceDays>=1, minNoticeHours>=0, cancelDeadlineHours>=0, maxFutureBookings>=1. Thành công 200 DTO sáu fields giống GET R01. Server lấy Clock sau policy exclusive transaction lock, truncate microseconds để khớp PostgreSQL, effectiveFrom UTC. Ghi updated_by từ principal. UPDATE active hiện có tại chỗ giữ ID, kể cả active tương lai sẽ thành hiệu lực ngay; không có active thì INSERT UUID mới. Bản inactive giữ nguyên. Không lưu lịch sử mỗi lần sửa active, không phải versioning đầy đủ, không snapshot policy trên booking.

READ_COMMITTED, timeout 10 giây; transaction advisory lock `(20261120,22)` exclusive cho PUT, shared cho GET và policy reads R03/R04. Hai PUT có thể đều 200, last-write-wins theo thứ tự khóa/commit; bảng trống vẫn an toàn. Readers lấy shared lock trước Clock/query và giữ đến hết transaction, thấy trọn cấu hình trước hoặc sau PUT, không nửa cập nhật. R03 thêm policy shared sau Member→membership→PT→slot; R04 Member cancel thêm sau Member→PT→slot→booking. PUT không khóa các tài nguyên booking, không đảo thứ tự khóa; không retry mù. R03 vẫn validate membership trước khi lookup policy với cùng locked time sample.

Giới hạn mới dùng cho create tiếp theo. Giảm maxFutureBookings không tự hủy/sửa bookings hoặc slots cũ. **Member cancel dùng cancelDeadlineHours hiệu lực lúc yêu cầu hủy**, kể cả booking đã tạo trước PUT: tăng deadline có thể từ chối yêu cầu hủy sau cập nhật; giảm deadline có thể cho phép. PUT không hồi tố chuyển state/time/owner của booking. Đây là hành vi R04 được giữ theo yêu cầu người dùng. D01 service-start check vẫn chưa có.

Không token/account đã khóa lúc auth: 401 ERR_UNAUTHORIZED; MEMBER/PT hoặc Admin mất ACTIVE sau chờ khóa: 403 ERR_FORBIDDEN; constraint/lock timeout/concurrency: 409 ERR_CONFLICT, envelope/correlation hiện hữu, không SQL/stack trace. PUT đầu tiên là lệnh cấu hình rõ ràng; GET không tự tạo policy và vẫn 404 khi không có hiệu lực. [Contract/traceability](decisions/2026-11-20_BOOKING_POLICY_WRITE.md) ghi lựa chọn lưu trữ và nguồn.

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

effectiveFrom là thời điểm UTC, ISO-8601; maxAdvanceDays dùng thời lượng ngày × 24 giờ theo D06 khi R03 tạo booking. GET chỉ đọc; task policy write bổ sung shared transaction lock trước Clock để chờ PUT nhất quán. Không token trả 401 `ERR_UNAUTHORIZED`; MEMBER/PT trả 403 `ERR_FORBIDDEN`, kể cả khi chưa có policy. Lỗi 404 dùng nguyên envelope hiện có: `success=false`, `status=404`, `error.code=BOOKING_POLICY_NOT_FOUND`, message, details, correlationId và timestamp; header X-Correlation-Id khớp body. Lock timeout/concurrency trả 409 ERR_CONFLICT. R01 chỉ có GET; PUT được bổ sung ở task policy write hiện tại.

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

Lỗi thường gặp: 400 `ERR_VALIDATION` cho input sai; 401 `ERR_UNAUTHORIZED` cho xác thực thất bại; 403 `ERR_FORBIDDEN` sai quyền; 404 `ERR_NOT_FOUND` nếu profile/plan/PT không có; 409 `ERR_CONFLICT` khi vi phạm dữ liệu; 500 `ERR_INTERNAL` cho lỗi không xử lý. Áp dụng tùy đường code, không hứa mọi endpoint phát sinh mọi mã. Envelope gồm `success:false`, `error:{code,message,details,correlationId}`, `timestamp`, `status`, `message`; có `X-Correlation-Id`. Ví dụ login/refresh dùng placeholder trong [cài đặt](03_LOCAL_SETUP_GUIDE.md). Booking create, Member/PT cancel, PT complete, policy write và API kiểm tra D01 đã có; membership/payment write và tích hợp Frontend chặn dịch vụ chưa triển khai.

## OpenAPI và giới hạn

[OpenAPI nháp](api/openapi.yaml) liệt kê các endpoint hiện có, role, DTO và tham số; cần review contract, ví dụ tổng hợp và kiểm tra bằng công cụ chuyên dụng trước khi công bố. Đặc tả và tài liệu này chưa có ví dụ request/response đầy đủ riêng cho từng endpoint và chưa phải contract hoàn chỉnh. Không dùng để tạo client production khi chưa review.

## M-03 — Admin initial Membership (rehearsal default-off)

POST `/api/v1/admin/members/{memberId}/activate-membership` (201 hoặc200 replay cùng key), GET `/api/v1/admin/members/{memberId}/membership-activation` (200 snapshot đã commit/404). ADMIN ACTIVE; Idempotency-Key UUID, memberId là profile UUID. Body planId/amountCollected/receiptRef/note, không client dates/owner. Receipt global chuẩn hóa, history bất kỳ chặn initial. Không đổi User hoặc tích hợp gateway. [Contract/error/transaction](decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md), [OpenAPI](api/openapi.yaml), [evidence](evidence/M03_INITIAL_MEMBERSHIP.md).

## MEMBER account activation — rehearsal default-off

POST `/api/v1/auth/member-activation/request-otp`, `/verify-otp`, `/password`: public202→200grant→200ACTIVE, không JWT. Chỉ roleMEMBER DISABLED có profile và nguồn Admin tạo; không cần Membership/không mutate payment. Role challenge/grant tách PT, cùng expiry/attempt/resend/lock/password contract. [Chi tiết](decisions/2026-11-23_MEMBER_ACCOUNT_ACTIVATION.md), [OpenAPI](api/openapi.yaml), [kiểm chứng](evidence/MEMBER_ACCOUNT_ACTIVATION.md).

## M-05/M-06 renewal — guarded rehearsal

Member tạo quote PENDING bằng POST `/api/v1/memberships/{id}/renewals` + Idempotency-Key; đọc `/payments/me`, `/payments/{id}`, `/memberships/{id}/periods`. Admin đọc `/admin/payment-simulator/transactions`, events và POST results. Amount DTO mới là decimal string, result request là JSON number. Không tự cấp quyền từ UI; SUCCESS có thể cần đối soát. [Contract đầy đủ/error/lock/period semantics](decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md), [OpenAPI](api/openapi.yaml). API chỉ bật bằng guarded renewal profile, mặc định503; không gateway. Các nhận định renewal chưa có phía trên là baseline lịch sử.

F-01 Core check-in/history: [contract](decisions/2026-11-24_F01_CHECKIN_CORE.md), [OpenAPI](api/openapi.yaml), [quickstart](22_CHECKIN_CORE_QUICKSTART.md), [evidence](evidence/F01_CHECKIN_CORE.md). Adapter identity chỉ simulated/test guarded default-off; không Face ID/liveness E2E.

F02 Admin Face enrollment: [contract](decisions/2026-11-24_F02_FACE_ENROLLMENT.md), [OpenAPI](api/openapi.yaml). Default-off/simulated, không client template identity.

## F03A — private Face Service/evaluation

[Contract/giới hạn](decisions/2026-11-24_F03A_FACE_SERVICE.md), [quickstart](24_FACE_SERVICE_QUICKSTART.md), [evidence](evidence/F03A_FACE_SERVICE.md), [private service OpenAPI](../../face/service_v2/openapi.json). Không endpoint public mới, không đổi default gates/migrations; actual PAD/accuracy/camera chưa được kiểm chứng.
