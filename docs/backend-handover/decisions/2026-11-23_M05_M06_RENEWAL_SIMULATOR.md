# M-05/M-06 — gia hạn và thanh toán mô phỏng

Ngày 23/11/2026; base I-01 `d2774c9`, branch `feature/membership-renewal-simulator`. Đây là rehearsal dev/test, không tích hợp gateway hoặc tiền thật.

## Quyết định người dùng đã duyệt

1. Giữ Membership UUID. Hết hạn: kỳ mới bắt đầu ngày hôm nay theo Clock Asia/Ho_Chi_Minh; gia hạn sớm nối sau ngày cuối đã thanh toán. N ngày có endDate=startDate+N−1, inclusive.
2. Gói khác chỉ thuộc kỳ gia hạn, không đổi kỳ đang dùng, không prorate.
3. Snapshot tên/gói/giá/thời lượng/VND tại initiation; settlement không đọc lại giá hoặc trạng thái plan. Giá 0 hợp lệ.
4. SUSPENDED/CANCELLED không tạo quote. SUCCESS khi trạng thái đã đổi ghi nhận tiền SUCCESS + RECONCILIATION_REQUIRED, không cấp kỳ hoặc tự mở khóa.
5. Hai SUCCESS độc lập cộng hai kỳ tuần tự; cùng yêu cầu/event retry không nhân đôi.
6. Simulator mặc định tắt, chỉ ACTIVE ADMIN điều khiển trong profile test được guard. Member không tự xác nhận kết quả.

## Contract đã triển khai

Mọi URL có prefix `/api/v1`. Tất cả response renewal no-store; UUID thật, thời gian instant UTC; ngày DATE là lịch Việt Nam. Amount mới là **chuỗi decimal hai chữ số** để tránh mất độ chính xác trong client. Đây không đổi DTO giá numeric của GET plan/M03.

| Role | Method/path | Contract |
|---|---|---|
| MEMBER ACTIVE | POST /memberships/{id}/renewals | Header Idempotency-Key UUID, JSON chỉ `{planId: UUID}`. 201 mới, 200 replay, header Idempotency-Replayed. |
| MEMBER ACTIVE | GET /payments/me | Array giao dịch renewal của mình, không quảng bá là toàn bộ lịch sử tiền quầy. |
| MEMBER ACTIVE | GET /payments/{id} | Một renewal thuộc mình, khác owner 404. |
| MEMBER ACTIVE | GET /memberships/{id}/periods | membershipId, checkedAt UTC, periods array; phase CURRENT/NEXT/HISTORY do server tính theo ngày VN. |
| ADMIN ACTIVE | GET /admin/payment-simulator/transactions | Array quote/payment renewal. |
| ADMIN ACTIVE | GET /admin/payment-simulator/transactions/{id}/events | Array trace an toàn: id/eventId/reportedStatus/outcome/errorCode/httpStatus/actorUserId/checkedAt. |
| ADMIN ACTIVE | POST /admin/payment-simulator/transactions/{id}/results | eventId UUID, providerRef, amount number NUMERIC(12,2), currency VND, status SUCCESS/FAILED/CANCELLED. HTTP 200 đã xử lý hoặc 409 có trace. |

Payment DTO: id, requestId (idempotency key), memberId, membershipId, planId, planName, amount, durationDays, currency, provider=SIMULATOR, providerRef=sim:UUID, status, fulfillmentStatus, reconciliationReason nullable, periodId/periodStart/periodEnd nullable, createdAt, processedAt nullable. Result thêm eventId/eventOutcome. Không nhận owner/status/giá từ Member. Strict JSON reader từ chối trường lạ, null/sai kiểu, decimal vượt precision/scale.

Cùng initiation key/payload trả lại cùng payment và snapshot gốc, kèm trạng thái hiện tại; không tính lại giá/ngày. Khác payload/owner: ERR_IDEMPOTENCY_KEY_REUSED. Cùng eventId/payload trả snapshot response đã lưu; khác payload trace ERR_PAYMENT_EVENT_KEY_REUSED. Event key global unique; (eventKey,fingerprint) unique để vừa giữ claim đầu vừa ghi được mâu thuẫn.

| Tình huống | Kết quả |
|---|---|
| PENDING + SUCCESS hợp lệ | SUCCESS/APPLIED, đúng một period, cập nhật ngày nguyên tử |
| PENDING + FAILED/CANCELLED | terminal, NOT_APPLIED, không đổi Membership |
| SUCCESS + SUCCESS | kết quả đã xử lý, không thêm period/audit; event mới có thể thêm trace |
| SUCCESS + FAILED/CANCELLED muộn | 409 ERR_PAYMENT_RESULT_CONFLICT, giữ SUCCESS |
| FAILED/CANCELLED + SUCCESS muộn | tiền SUCCESS, RECONCILIATION_REQUIRED/LATE_SUCCESS_AFTER_TERMINAL, không cấp quyền tự động |
| Snapshot/reference/amount/currency không khớp | 409 ERR_PAYMENT_RESULT_MISMATCH, trace, không mutation quyền |
| Membership đổi trạng thái trước settlement | SUCCESS/RECONCILIATION_REQUIRED/MEMBERSHIP_STATE_CHANGED |
| Ngày vượt miền PostgreSQL khi settlement | SUCCESS/RECONCILIATION_REQUIRED/PERIOD_DATE_RANGE |

Các lỗi khác dùng envelope hiện có error.code/correlationId: ERR_RENEWAL_UNAVAILABLE(503), ERR_NOT_FOUND(404), ERR_MEMBERSHIP_NOT_RENEWABLE/ERR_MEMBERSHIP_COVERAGE_UNKNOWN/ERR_PLAN_NO_LONGER_AVAILABLE/ERR_RENEWAL_CONFLICT(409), ERR_RENEWAL_DATE_RANGE(400). Không JWT 401; sai role 403; JWT của account đã khóa bị filter từ chối 401. PENDING_ACTIVATION chưa có coverage không bị tự biến thành initial activation; phải đi M03. Không có workflow refund/đối soát thủ công trong task này; trace/reason là đầu vào task sau.

## Transaction và lịch sử

Writer READ_COMMITTED, timeout10s. Khóa **Member NO KEY UPDATE → Membership FOR UPDATE → payment/quote FOR UPDATE → event claim**. Không đường nào khóa event rồi Member. Initiation khóa plan FOR SHARE để lấy snapshot nhất quán. Recheck ACTIVE actor và trạng thái dữ liệu sau chờ; Clock quyết định sau khóa. Cùng Member serializes initiation/settlement với R03/R04/M03; không khóa User theo thứ tự ngược. Unique constraints là lớp cuối; không retry write mù.

Membership, period, payment, quote, event, audit trong cùng transaction. Conflict dự kiến được ghi trace rồi throw envelope **sau commit trace**; lỗi nội bộ rollback toàn bộ. Read dùng REPEATABLE_READ/readOnly để DTO/periods không trộn snapshot. Hai settlement độc lập cùng Member append theo last paid end dưới cùng khóa.

Không ghi đè memberships.plan_id bằng plan tương lai. M04 giữ array/fields cũ, plan là kỳ CURRENT hoặc kỳ cuối đã kết thúc; không chọn NEXT. startDate/endDate là envelope đoạn coverage liên tục hiện tại/gần nhất, không phải period breakdown; UI dùng endpoint periods mới để thể hiện từng kỳ. Khi hết hạn rồi gia hạn, start_date bắt đầu lại hôm nay; history cũ ở period rows giữ nguyên. Booking/D01, khi feature bật, phải có paid coverage hôm nay và cả session; ghép các kỳ liền kề, không bắc cầu qua ngày chưa trả tiền. Không thêm start marker hoặc đổi completion R04.

## Schema và release gate

[V11 additive](../../../database/renewal-rehearsal/V11__membership_renewal_simulator.sql) tạo membership_paid_periods, renewal_payment_quotes, renewal_result_keys, renewal_payment_events; giữ nguyên payment period_start/end, M03 receipt/snapshots/audit và activation state. M03 initial backfill dùng đúng payment period + receipt snapshots; nếu ngày Membership khác payment thì fail closed. Legacy có ngày nhưng không có provenance nhận LEGACY_AGGREGATE, price/duration/name unknown (null); không giả lịch sử hoặc giá hiện nay. Exclusion range cấm period overlap, các FK owner và unique payment/key bảo vệ race.

Location chỉ `db/renewal-rehearsal`; profile `renewal-integration-rehearsal` được guard loopback15441/role/database namespace và năm locations. Gates production/default vẫn tắt. Frozen candidate **1–6,8,9,10,11** trong [manifest](../../../database/renewal-integration-candidate.json); V7 remote database558fb03 vẫn quarantine vì DROP payment periods chưa backfill. V8–V11 không đổi số/SQL đã áp. Shared DB inventory chưa biết, V7 có thể đã áp nơi khác. **releaseReady=false**: cần inventory/checksum, kế hoạch bảo toàn dữ liệu V7 và đồng bộ Duy trước merge/release; không out-of-order/history edits/clean/repair.

[Evidence](../evidence/M05_M06_RENEWAL_SIMULATOR.md), [quickstart](../21_RENEWAL_SIMULATOR_QUICKSTART.md).
