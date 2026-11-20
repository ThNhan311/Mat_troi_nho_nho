# Contract R04 cancellation và completion

Nguồn: người dùng giao R04 ngày 20/11/2026; Topic11_FITCENTER.docx UC-11/15/16 (1.5.6), AC-BKG-04..09; [D01–D07](2026-11-20_BOOKING_DECISIONS.md), [V4](../../../database/migrations/V4__pt_booking.sql) và [giao thức R03](2026-11-20_R03_BOOKING_CREATE.md). Bản Topic11 ngoài repository có SHA256 `5E2164806B4927390E986712E04D53BEE09255A3EAC9AB33997BC4FF6F6A47B5`, đọc nội dung OOXML, không dẫn số trang chưa kiểm chứng.

R03 đã đóng bằng commit local `394a21f96c7c7458cc109c9f56a174beb1ccf62b`. R04 trên feature/backend-booking-lifecycle, chưa commit. Contract và phương án khóa dưới đây đã được ghi/báo trước coding.

## Response và error

Ba POST theo task, thành công **200 BookingResponse** hiện hữu: id,memberId,ptId,slotId,startAt,endAt,status,cancelledBy,cancelReason,cancelledAt,completedAt. Timestamps UTC; identity từ principal và profile, không dùng actor/owner trong body. Các endpoint chỉ chuyển từ CONFIRMED. Request lặp sau CANCELLED/COMPLETED trả 409 ERR_BOOKING_NOT_CONFIRMED, không cập nhật metadata hoặc slot.

Member cancel không cần body; cancelledBy=MEMBER, cancelReason=null, cancelledAt=now, completedAt=null. Dùng policy hiệu lực R01 tại Clock now, không fallback; thiếu/inactive/future giữ 404 BOOKING_POLICY_NOT_FOUND. Điều kiện start-now >= cancelDeadlineHours, equality cho phép. Không kiểm membership ACTIVE hoặc tái dùng create eligibility. Slot còn tương lai (start>now) trở lại AVAILABLE; tại start với deadline=0 được phép chuyển nhưng slot DISABLED để không mở lại slot đã qua/đang bắt đầu.

PT cancel nhận JSON reason, không null/thiếu/blank (gồm whitespace Unicode); tối đa 500 Unicode code points như PostgreSQL VARCHAR(500). Lưu nguyên văn, không trim lý do hợp lệ; cancelledBy=PT, cancelledAt=now, completedAt=null; slot DISABLED. Chỉ PT ACTIVE sở hữu booking CONFIRMED, **now < startAt**. Clock lấy sau khi chờ đủ khóa và recheck booking, không dùng giờ request đến. Không yêu cầu policy hoặc membership của Member ACTIVE. Complete không cần body, now>=endAt, completedAt=now, metadata hủy null, slot DISABLED. Completion không thay thế D01 service-start eligibility check.

Lỗi input/UUID/reason: 400 ERR_VALIDATION; token không hợp lệ/account không ACTIVE khi auth: 401 ERR_UNAUTHORIZED; sai role hoặc account không còn ACTIVE khi recheck: 403 ERR_FORBIDDEN; missing profile/booking/không sở hữu: 404 ERR_NOT_FOUND. Business conflict: 409 ERR_BOOKING_NOT_CONFIRMED, ERR_CANCELLATION_DEADLINE, **ERR_PT_CANCELLATION_WINDOW_CLOSED khi now>=startAt**, ERR_BOOKING_NOT_ENDED, ERR_BOOKING_SLOT_CONFLICT. Constraint/concurrency: 409 ERR_CONFLICT. Mọi lỗi theo envelope/correlation hiện hữu, không SQL/stack trace, không retry mù. Với reason hợp lệ, terminal state được kiểm trước cửa sổ thời gian để request lặp luôn nhận ERR_BOOKING_NOT_CONFIRMED; reason sai là input 400.

## Quyết định PT cancellation đã chốt

Topic11 yêu cầu PT cancel có reason nhưng không nói rõ có được hủy khi session đã bắt đầu/kết thúc. Ban đầu đã hỏi và chỉ triển khai phần độc lập. **Người dùng sau đó chốt phương án 1:** chỉ trước startAt; bằng/sau trả 409 ERR_PT_CANCELLATION_WINDOW_CLOSED, không yêu cầu membership ACTIVE. OPEN-R04-PT-TIME đã đóng. Đây là nguồn quyết định bổ sung từ người dùng, không gán quy tắc này cho Topic11. Endpoint và tests PT cancel chỉ được thêm/chạy sau quyết định; kết quả 499 của lượt độc lập không phải bằng chứng API PT cancel đã chạy.

## Transaction và khóa

READ_COMMITTED, timeout 10 giây. Đọc projection chỉ chứa memberId/ptId/slotId của booking, kiểm actor/profile/ownership; không load booking entity trước khi khóa. Khóa **Member → PT → slot → booking**; không khóa membership vì không cần đọc dữ liệu eligibility. Member/PT dùng FOR NO KEY UPDATE, slot và booking dùng PESSIMISTIC_WRITE. Sau khóa, đọc booking entity mới, recheck identity/ownership/CONFIRMED, account principal và slot snapshot; không dùng entity stale.

Mọi lifecycle thay count/overlap đều giữ Member lock, tương thích R03 (Member → membership → PT → slot) và R02 (PT → slot). R03/R02 không giữ booking lock rồi quay lại khóa Member/PT/slot, nên thêm booking cuối không tạo thứ tự khóa ngược. Khóa PT/slot còn bảo vệ cancel rồi rebook giữa hai Member. Trước đổi slot, kiểm không có CONFIRMED khác trên slot. Booking và slot flush/commit nguyên tử; lỗi rollback cả hai. Khi request cũ đến sau rebooking, trạng thái booking cũ bị kiểm tra lại và trả 409 trước mọi mutation, không mở/vô hiệu hóa slot của booking mới.

Giữ nguyên thời gian/identity ghép của slot và booking, không hard delete hoặc sửa V1–V6. Không thêm PENDING/REJECTED/RESCHEDULED, policy PUT, membership/payment write hoặc Face. D07 PT cancel/completion đã có code và kiểm thử sau quyết định; D01 recheck trước dịch vụ vẫn chưa triển khai.

## Traceability R04

| Nguồn/quy tắc | Code | Bằng chứng |
|---|---|---|
| UC-11, AC-BKG-04/05/08; D02/D03/D04 | BookingLifecycleService.memberCancel, R01 policy, BookingLifecycleValidator | HTTP deadline trước/bằng/sau, custom/missing policy, membership inactive vẫn hủy, slot available và rebook |
| UC-16, D07 completion | BookingLifecycleService.complete | Clock trước/bằng/sau end, completedAt, slot DISABLED, policy/membership không bị dùng làm service-start check |
| Chỉ CONFIRMED; yêu cầu request lặp 409 | requireConfirmed sau booking lock | CANCELLED/COMPLETED không chuyển lại, metadata không thay; request cũ sau rebook không đổi booking/slot mới |
| R02/R03 giao thức khóa; AC-BKG-08 | Member → PT → slot → booking, projection BookingLink | Race cancel/cancel, complete/complete, Member cancel/complete, cancel/rebook, lifecycle/PATCH/DELETE; hai request cùng chờ khóa trước release |
| Atomic state/FK | Flush booking terminal rồi slot trong cùng transaction | Member exclusion fail rollback metadata; PT cancel service thật trong outer transaction, xác nhận cả hai rows đã flush rồi abort và kiểm snapshot sau rollback; không sửa migration hoặc trigger |
| UC-15, AC-BKG-06/09; D07 PT cancel; quyết định người dùng now<startAt | BookingLifecycleService.ptCancel, BookingLifecycleValidator.ptCancellation/reason | HTTP trước/bằng/sau, Clock sau chờ khóa, account recheck, reason Unicode, metadata/slot DISABLED, repeat/old requests; races PT/PT, PT/Member, PT/complete, PT cancel/create/rebook/PATCH/DELETE |

Code: [service](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleService.java), [controller](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/controller/BookingLifecycleController.java), [validator](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleValidator.java), [unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/service/BookingLifecycleValidatorTest.java), [HTTP](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java). Kết quả thực và source hashes ở [báo cáo R04](../evidence/R04_BOOKING_LIFECYCLE.md).
