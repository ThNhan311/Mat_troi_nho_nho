# Backlog tiếp nhận

Cập nhật Policy write: R04 commit local `8cb95e2`; nhánh feature/backend-booking-policy-write thêm Admin PUT hiệu lực ngay theo D05, [contract](decisions/2026-11-20_BOOKING_POLICY_WRITE.md), [báo cáo](evidence/BOOKING_POLICY_WRITE.md). Giữ task chưa commit; không có scheduling/versioning đầy đủ, membership/payment write hoặc D01 service-start check. Các dòng chưa PUT ở checkpoint R04 trở về trước là lịch sử.

Cập nhật R04: R03 đã commit local `394a21f`; nhánh feature/backend-booking-lifecycle có Member/PT cancellation và PT completion, chưa commit. OPEN-R04-PT-TIME đã chốt PT chỉ hủy trước startAt; xem [báo cáo R04](evidence/R04_BOOKING_LIFECYCLE.md). Snapshot R04 “PT duyệt/từ chối” bên dưới không thuộc quy trình auto-confirm đã chốt; R04 thực tế được người dùng giao ở phiên này là cancel/complete, không thêm PENDING/REJECTED. D01 service-start recheck, policy PUT và membership/payment write vẫn chưa có.

Cập nhật R03: R02 đã đóng bằng commit local `4d137d7`. R03 được giao và triển khai auto-confirm Member booking trong working tree `feature/backend-booking-create`, cùng kiểm tra membership/policy, khóa Member/PT/slot và rollback. Xem [báo cáo](evidence/R03_BOOKING_CREATE.md), [traceability](decisions/2026-11-20_R03_BOOKING_CREATE.md). Các mô tả R03 bị chặn trong snapshot bên dưới đã được cập nhật này thay thế. Cancel/complete, policy PUT và membership write chưa triển khai; PT approve/reject không thuộc baseline đã chốt.

Cập nhật R02: R01 đã commit local `9ae0a50`. R02 đã được người dùng giao chính thức, triển khai availability POST/PATCH/DELETE và kiểm thử trên working tree `feature/backend-pt-availability-write`; xem [báo cáo](evidence/R02_PT_AVAILABILITY_WRITE.md) và [contract](05_API_DOCUMENTATION.md). Các trạng thái R01/R02 chờ duyệt trong snapshot bên dưới đã được cập nhật này thay thế. R03 trở đi chưa triển khai; không thêm PT approve/reject trái auto-confirm D01–D07.

Cập nhật 20/11/2026: [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md) đã được người dùng chốt. R01 được giao và triển khai trong working tree sau Task A commit 073e131; contract đọc policy không còn chờ OPEN-POL-01. Bảng/đặc tả đề xuất ban đầu bên dưới là snapshot bàn giao; các luồng ghi R02–R07 vẫn chưa triển khai và không thuộc R01. Xem [API hiện tại](05_API_DOCUMENTATION.md) và [báo cáo R01](evidence/R01_BOOKING_POLICY_READ.md).

Đây là đề xuất, không cấp quyền triển khai. Trước mỗi task xác nhận phạm vi và quy tắc tại [nghiệp vụ](07_BUSINESS_RULES_AND_BLOCKERS.md). File dự kiến là vị trí đề xuất, không khẳng định đã tồn tại.

| ID / ưu tiên | Mục tiêu, trạng thái và phụ thuộc | Source, API/file dự kiến | Kiểm thử và tiêu chí chấp nhận |
|---|---|---|---|
| R01 / cao | Đọc policy; có bảng, chưa có API; xác nhận quyền ADMIN | V4, SecurityConfig; thêm controller/service/repository policy; GET admin đề xuất | Test quyền, không có policy, response; đọc đúng bản hiệu lực |
| R02 / cao | PT quản lý availability; chưa có write; chờ quy tắc overlap | AvailabilityService, V4; thêm API tạo/sửa slot | Test role, ownership, overlap và concurrency; không làm sai booking |
| R03 / cao | Member tạo booking; bị chặn bởi xác nhận duyệt, membership, policy | BookingQueryService, V4; POST booking đề xuất | Test ownership, membership, transaction, race; không trùng slot |
| R04 / cao | PT duyệt/từ chối nếu được duyệt; xung đột V4 | V4, BookingStatus; migration mới và API đề xuất | Test trạng thái, migration và concurrency; phê duyệt schema trước |
| R05 / cao | Hủy/hoàn thành; chờ quy tắc slot/deadline | V4, BookingQueryService; API chuyển trạng thái đề xuất | Test role, lý do, deadline, đồng bộ slot và rollback |
| R06 / cao | Activation/renewal; chờ quy tắc periods và lịch sử | V2, V7 nhánh database; service/migration mới sau duyệt | Test chuyển dữ liệu, idempotency, ngày Việt Nam; bảo toàn lịch sử |
| R07 / cao | Payment; chờ provider và policy | V2 payment; controller/service/repository đề xuất | Test callback trùng, transaction, bảo mật; mỗi giao dịch áp dụng một lần |
| R08 / vừa | Face/check-in, workout, notification, audit; schema có, nghiệp vụ thiếu | V3/V5/V6; module/API mới theo đặc tả | Test tích hợp và quyền; đối chiếu chủ module |
| R09 / vừa | Tích hợp frontend; phụ thuộc contract đã duyệt | API hiện tại, worktree frontend riêng; client tương ứng | Test role, lỗi, timezone và contract end-to-end |
| R10 / cao | Regression; sau từng thay đổi | Test hiện hữu và DB test riêng | Full suite, integration và HTTP có bằng chứng, báo rõ skipped |

R01 có thể thiết kế sau xác nhận contract/quyền; không khẳng định được phép viết ngay khi chưa duyệt. R02–R07 phụ thuộc quyết định nghiệp vụ hoặc schema; không tự triển khai.

## Đặc tả đề xuất R01: Admin đọc Booking Policy

- Priority cao; trạng thái chờ duyệt contract và OPEN-POL-01. Mục tiêu cho Admin đọc policy được xác định hiệu lực; không tạo default.
- Source: `database/migrations/V4__pt_booking.sql`, `SecurityConfig` đã có matcher `/api/v1/admin/**`; chưa có entity/repository/service/controller policy. Cần xác nhận đường dẫn HTTP, response, quyền, cách xét `active` và `effective_from`, timezone và phản hồi khi không có policy. Không tự xác định ý nghĩa từ unique index.
- Phạm vi sau duyệt: DTO, query, service, endpoint read-only và bảo mật; ngoài phạm vi: chỉnh policy, tự tạo policy, sửa migration. Đường dẫn API là đề xuất cần duyệt, chưa đưa vào API hiện có.
- Test: ADMIN đọc đúng policy theo quyết định; MEMBER/PT/ẩn danh bị chặn; kiểm tra không có row, policy tương lai, ranh giới timestamp, payload, lỗi, DB integration trên DB riêng và security tests. Acceptance: contract và kết quả khớp quyết định đã ghi; không rò dữ liệu hoặc tự tạo policy. DoD: review, test phù hợp, cập nhật contract và giới hạn, báo cáo kết quả và skipped.

Các R02–R10 trong bảng trên vẫn là backlog sơ bộ, chưa đủ task specification hoặc Definition of Done riêng để giao chính thức.
