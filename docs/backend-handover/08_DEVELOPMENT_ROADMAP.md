# Backlog tiếp nhận

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
