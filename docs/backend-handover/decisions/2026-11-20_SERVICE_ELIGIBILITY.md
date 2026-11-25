# D01 phương án A — kiểm tra eligibility hiện tại

Nguồn: người dùng chốt phương án A ngày 20/11/2026; Topic11 AC-BKG-07/TC-BKG-06 và [D01](2026-11-20_BOOKING_DECISIONS.md). Bản Topic11 ngoài repository đã đọc OOXML khi khảo sát, SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`; không suy ra trang. AC-BKG-07 yêu cầu chặn dịch vụ khi membership inactive tại session time cho tới khi ACTIVE. Cửa sổ/account/contract cụ thể dưới đây do người dùng chốt trong task này, không gán thêm cho nguồn.

Base commit `63fe3945715888c7cbc9ad436c65d0e7f16273de`; nhánh feature/backend-service-eligibility được tạo sau xác minh tên chưa tồn tại. Task chưa stage/commit; không push/merge. Thiết kế này được ghi/báo trước coding.

GET `/api/v1/pt/bookings/{id}/service-eligibility`, chỉ PT ACTIVE có profile sở hữu booking. UUID path; identity/ownership từ principal và booking.pt_id, không dùng memberId/ptId query client. Query parameters ngoài contract không thay ownership. Thiếu token/account không ACTIVE khi auth: 401 ERR_UNAUTHORIZED; sai role hoặc account PT không ACTIVE trong snapshot service: 403 ERR_FORBIDDEN; missing profile/booking/không sở hữu: 404 ERR_NOT_FOUND; UUID sai: 400 ERR_VALIDATION. Dùng error envelope/correlation hiện có.

PT được phép truy cập nhận **200** đúng ba fields `eligible`, `checkedAt` (server Clock, ISO-8601 UTC), `reasonCodes` (mảng có thứ tự cố định, không trùng). eligible=true khi và chỉ khi mảng rỗng; không trả Member ID/name, membership ID/status/dates hoặc PII khác. `Cache-Control: no-store`, không cache kết quả phía backend.

| Reason code | Điều kiện |
|---|---|
| BOOKING_NOT_CONFIRMED | Booking CANCELLED/COMPLETED, vẫn 200 nếu PT đúng owner |
| SESSION_NOT_STARTED | now < startAt |
| SESSION_ENDED | now >= endAt |
| MEMBER_ACCOUNT_INACTIVE | User gắn Member không còn role MEMBER hoặc không ACTIVE |
| MEMBERSHIP_INACTIVE | Không có membership hiện hành chưa CANCELLED, stored status không ACTIVE, thiếu dates hoặc now ngoài thời hạn |
| MEMBERSHIP_NOT_COVERED | Membership ACTIVE và đang hiệu lực nhưng không phủ toàn bộ `[startAt,endAt)` |

Thu thập mọi lý do độc lập theo thứ tự bảng; SESSION_NOT_STARTED/SESSION_ENDED loại trừ nhau theo schema. Nếu membership không hợp lệ hiện tại, chỉ ghi MEMBERSHIP_INACTIVE cho nhóm membership; coverage được kiểm khi membership hiện hành hợp lệ, theo thứ tự R03. Tái dùng riêng pure membership validation R03: start_date 00:00 Asia/Ho_Chi_Minh inclusive, expiry_date hết ngày inclusive, end đúng 00:00 ngày sau expiry được phép. Không áp notice/advance/max-future/cancellation policy, không đọc hoặc tự tạo booking policy.

Transaction **readOnly=true, isolation=REPEATABLE_READ, timeout=10 giây**. SELECT account principal đầu tiên thiết lập PostgreSQL MVCC snapshot; Clock lấy một lần trong transaction sau SELECT đó. Profile/booking/member account/current membership đều đọc cùng snapshot. Query membership riêng không có PESSIMISTIC_READ (khác query R03 đang dùng row lock). Không UPDATE/INSERT, SELECT FOR UPDATE hoặc policy advisory lock, nên không thêm thứ tự khóa hàng với writers R02/R03/R04/policy. Writer có thể commit khi GET đang chạy; GET trả bộ dữ liệu cũ nhất quán, lần GET mới nhận snapshot mới. checkedAt là thời điểm server đánh giá snapshot đọc này, không phải chứng nhận các hàng không đổi hoặc quyền sử dụng lâu dài sau response.

D01 có API kiểm tra phía Backend trong task này; Frontend chưa tích hợp thì không tuyên bố luồng chặn dịch vụ end-to-end hoàn tất. Không có startedAt/startedBy, IN_PROGRESS, migration hoặc phương án B. Completion giữ nguyên R04 (CONFIRMED, now>=endAt), không yêu cầu GET trước đó, không thay cancellation. Không sửa V1–V6, áp V7 hoặc phát triển Membership/Payment/Face.

## Traceability

| Nguồn/quy tắc | Code | Bằng chứng |
|---|---|---|
| AC-BKG-07/TC-BKG-06, D01; Member account ACTIVE | ServiceEligibilityValidator, riêng validateMembership R03 | HTTP membership missing/inactive/not-started/expired, account SUSPENDED/DISABLED, khôi phục ACTIVE rồi GET mới; DATE Việt Nam/coverage start/end |
| Cửa sổ [startAt,endAt) do người dùng chốt | ServiceEligibilityValidator | Unit nanosecond, HTTP microsecond trước/bằng/sau start/end, terminal bookings trả 200 false |
| PT ACTIVE/ownership từ principal | ServiceEligibilityService, SecurityConfig hiện có | ADMIN/MEMBER 403, anonymous/PT khóa 401, PT khác/missing ID 404, UUID sai 400, query owner IDs không bypass |
| Minimal response/no-store/no mutation | ServiceEligibilityResponse, ServiceEligibilityController | Đúng ba fields, UTC checkedAt/ordered reasonCodes, header no-store và full DB snapshots trước/sau GET |
| Snapshot nhất quán, không thêm khóa hàng | REPEATABLE_READ service, membership query không @Lock | Latch tại test Clock sau first SELECT; account+membership SQL commit và Member cancel HTTP commit trước reads còn lại; GET cũ nhất quán/GET mới thấy state mới |
| Không policy/reapply creation rules, không marker/đổi complete | Pure membership validation; lifecycle R04 không sửa | No/restrictive policy vẫn eligible; complete khi chưa GET hoặc sau GET false vẫn theo R04 |

Code: [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/ServiceEligibilityController.java), [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityService.java), [validator](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityValidator.java), [unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/ServiceEligibilityValidatorTest.java), [HTTP/DB](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java). [Báo cáo kết quả/hash](../evidence/SERVICE_ELIGIBILITY.md).
