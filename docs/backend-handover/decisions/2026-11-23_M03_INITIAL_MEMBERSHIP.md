# M-03 — quyết định và contract đã triển khai

Ngày23/11/2026, từ M-04 `92328e0`; nhánh `feature/admin-membership-initial-activation`. Nguồn: chỉ thị người dùng phê duyệt M-03 trong phiên, Topic11 UC-20/PD-03 và [khảo sát nguồn](../proposals/2026-11-23_M03_SOURCES.json). [Bản đề xuất trước phê duyệt](../proposals/2026-11-23_M03_COUNTER_ACTIVATION.md) là lịch sử, không lấn át quyết định này.

## Nghiệp vụ đã chốt

- Admin ACTIVE ghi nhận khoản **đã thu tại quầy** cho Member profile đã tồn tại. Không phải thu tiền/gateway. Không yêu cầu Member account ACTIVE, không sửa User/password/JWT. MEMBER email→OTP→password là task tiếp theo đã đồng ý, chưa triển khai tại đây.
- Initial chỉ khi chưa từng có bất cứ Membership nào, kể cả PENDING/EXPIRED/SUSPENDED/CANCELLED. Không renewal/reactivation, không sửa lịch sử.
- Clock sau chờ khóa, ngày Asia/Ho_Chi_Minh; start=today, end=start+durationDays−1, expiry inclusive. Không client date. DATE quá phạm vi PostgreSQL bị validation400, không thêm business cap cho duration.
- Plan phải ACTIVE; giá/duration server đọc khi xác nhận, hỗ trợ0. UI gửi amountCollected đúng giá đã xem để xác nhận chứng từ, không có input sửa giá. Giá đã đổi ->409 ERR_AMOUNT_MISMATCH, không tự ghi nhận giá mới chưa xác nhận. Giá/duration/name/dates áp dụng được lưu snapshot.

## Contract và lựa chọn kỹ thuật

POST `/api/v1/admin/members/{memberId}/activate-membership`, memberId là profile UUID, Idempotency-Key bắt buộc UUID. Body chỉ `planId` UUID, `amountCollected` JSON number NUMERIC(12,2) >=0, `receiptRef` string bắt buộc, `note` string/null tùy chọn. Không field ID/status/owner/date client, unknown/duplicate field bị400. Quyền ADMIN ACTIVE lấy principal và recheck sau chờ khóa.

Receipt: NFC + strip whitespace ngoài; khóa duy nhất toàn hệ thống là uppercase Locale.ROOT, giữ nguyên whitespace bên trong. Receipt hiển thị giữ case của lần ghi nhận đầu; cả chuỗi đã chuẩn hóa và khóa uppercase tối đa100 Unicode code points. Note NFC/strip, blank thành null, tối đa500 code points. Không NUL. Đây là lựa chọn chuẩn hóa kỹ thuật được công bố, không unique theo Member.

Fingerprint SHA256 command-version + memberId + planId + amount 2 chữ số + receiptKey + note. Không bao gồm Admin actor: Admin hợp lệ khác retry cùng command/key nhận snapshot gốc, actor gốc giữ nguyên. Key UUID global, phân biệt payload sau chuẩn hóa. Cùng key/payload ->200 và DTO gốc, không tính lại giá/ngày hoặc ghi audit lần hai; khác payload ->409 ERR_IDEMPOTENCY_KEY_REUSED. Receipt đã dùng cho request khác ->409 ERR_RECEIPT_ALREADY_USED. Cùng Member khác key ->409 ERR_MEMBERSHIP_ALREADY_EXISTS.

Lần đầu201; replay200. DTO object có activationId/requestId/memberId, membership(id,planId,planName,startDate,endDate,status ACTIVE), payment(id,provider COUNTER,providerRef,amount,status SUCCESS,processedAt), receipt(receiptRef,note,confirmedByUserId,confirmedAt), planSnapshot(name,durationDays,listedPrice,currency VND). Các timestamp UTC; DATE không đổi qua UTC. Header Cache-Control no-store và Idempotency-Replayed.

GET `/api/v1/admin/members/{memberId}/membership-activation`: ADMIN ACTIVE đọc snapshot chứng từ **đã commit** để đối chiếu sau mất mạng/reload,200; chưa có404 ERR_NOT_FOUND. Đây không phải API đọc trạng thái Membership hiện tại và không chứng minh POST đang chờ đã thất bại. Không sửa booking cũ. Frontend không tạo key mới/replay write mù khi chưa rõ kết quả; GET đối chiếu rồi chỉ retry thủ công cùng key/payload đang giữ. Reload mất command đang chờ trong memory nhưng đọc chứng từ theo Member vẫn được; không suy đoán thành công khi404.

Lỗi envelope hiện có error.code/message/details/correlationId:401 không token,403 role/account,400 ERR_VALIDATION input/UUID/key,404 ERR_NOT_FOUND Member/plan/receipt không thấy;409 các mã trên, ERR_PLAN_NO_LONGER_AVAILABLE, ERR_AMOUNT_MISMATCH, ERR_CONFLICT;503 ERR_MEMBERSHIP_ACTIVATION_UNAVAILABLE khi gate tắt. SQL/stack trace không lộ HTTP.

## Transaction và khóa

READ_COMMITTED, timeout10s. Khóa Member FOR NO KEY UPDATE trước (cùng thứ tự Booking R03/R04, không khóa User), kiểm idempotency, khóa lịch sử Membership theo id FOR UPDATE, khóa Plan FOR SHARE. Lấy Clock và recheck actor sau chờ. Không khóa PT/slot/Booking. Cùng Member được serialize; các Member khác tranh key/receipt bị UNIQUE constraints phân xử. Constraint conflict rollback transaction trước, rồi transaction đọc mới phân loại winner/replay409; không retry write tự động.

Membership ACTIVE + payment SUCCESS/COUNTER/V2 period_start/end + receipt/snapshot/idempotency + audit USER/MEMBERSHIP_INITIAL_ACTIVATED commit nguyên tử. Hai composite FK đảm bảo payment/membership cùng Member. User/Booking/slot/policy/legacy payment không bị cập nhật. GET readback chỉ đọc một snapshotJSONB đã commit; không đọc nửa bộ dữ liệu.

## Schema rehearsal và giới hạn phát hành

[V9 rehearsal](../../../database/membership-rehearsal/V9__membership_initial_activation.sql) thêm đúng bảng membership_initial_activations và2 UNIQUE identity keys làm composite FK targets; không sửa V1–V6/V8 hoặc xóa/chuyển payment periods. Các comment `proposed/case-sensitive` trong SQL đã apply là dấu lịch sử lúc chuẩn bị; quy tắc thực thi là receiptKey uppercase/VND nêu ở trên. Giữ nguyên bytes/checksum migration đã apply.

V9 chỉ location `db/membership-rehearsal`, profile `membership-rehearsal`, enabled mặc định false. Guard loopback15440, role không admin, tên DB/nonce, flag và locations kiểm trước Flyway. PT activation vẫn false. Test riêng history1–6,9 **không phải DB release**. V7 tại database558fb03 DROP period_start/end trước backfill, không áp. Validate-only chứng minh V7 đến muộn bị từ chối khi outOfOrder=false; không sửa history/repair/clean. V8 PT location khác, không cần apply để M-03 chạy.

Trước merge/release cần Duy thống nhất version/order và V7 backfill giữ payments SUCCESS/REFUNDED/FAILED/CANCELLED/PENDING/NULL membership. COUNTER SUCCESS của M-03 là initial có transaction, không được suy từ SUCCESS thành RENEWAL hoặc model ACTIVATION không tx. Không phát hành mặc định cho đến khi có chuỗi migration bảo toàn lịch sử được kiểm lại.

[Evidence](../evidence/M03_INITIAL_MEMBERSHIP.md) · [Chạy lại](../18_INITIAL_MEMBERSHIP_QUICKSTART.md).
