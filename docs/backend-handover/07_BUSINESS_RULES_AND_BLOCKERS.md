# Nghiệp vụ và quyết định chờ

Cập nhật R04: đã có Member/PT cancel và PT complete trên working tree. **OPEN-R04-PT-TIME đã đóng bởi quyết định người dùng**: PT chỉ hủy CONFIRMED khi now < startAt; đúng bằng/sau startAt trả 409 ERR_PT_CANCELLATION_WINDOW_CLOSED. Đây là quyết định bổ sung vì Topic11 UC-11/15/16 không xác định tình huống này. Xem [contract R04](decisions/2026-11-20_R04_BOOKING_LIFECYCLE.md). D01 service-start recheck vẫn chưa có; completion không thay thế bước này.

Cập nhật R03: eligibility lúc đặt, policy notice/advance/count, auto-confirm và concurrency đã có working tree theo [D01–D07](decisions/2026-11-20_BOOKING_DECISIONS.md) và [quy tắc DATE/lock R03](decisions/2026-11-20_R03_BOOKING_CREATE.md). Không có blocker schema cho phạm vi này; giữ nguyên V1–V6. Kiểm tra membership trước bắt đầu dịch vụ, cancel/complete và policy/membership write vẫn chưa có. Các bảng “chờ chốt/chưa booking write” bên dưới là snapshot lịch sử, không phủ nhận cập nhật R03.

Cập nhật R02: đã đọc Topic11_FITCENTER.docx do người dùng cung cấp ngày 20/11/2026; UC-13 xác nhận PT quản lý availability và Core session 90 phút. Contract ghi và lựa chọn bảo toàn FK/lịch sử ở [quyết định R02](decisions/2026-11-20_R02_AVAILABILITY.md). Không còn blocker quyết định cho phạm vi availability đã giao; các tuyên bố thiếu nguồn/chưa có availability write bên dưới là snapshot trước R02, không phải kết luận mới.

Cập nhật tiếp nhận 20/11/2026: người dùng đã chốt auto-confirm theo Topic11 và D01–D07 trong [sổ quyết định](decisions/2026-11-20_BOOKING_DECISIONS.md). Các mục chờ tương ứng trong bảng snapshot dưới đã được quyết định đó thay thế. Quy tắc được chốt không đồng nghĩa các luồng ghi đã triển khai; R01 mới thêm policy read.

Phân loại dưới đây dựa trên schema/code và báo cáo có trong checkout; chưa xác minh tài liệu SRS/UC/BR đầy đủ hay quyết định mới nhất từ nhóm. Comment SQL không thay thế xác nhận nghiệp vụ.

| Vấn đề | Bằng chứng và trạng thái |
|---|---|
| Booking xác nhận ngay hay PT duyệt | V4 chỉ CONFIRMED/CANCELLED/COMPLETED; PENDING/REJECTED xung đột DB. Chờ nhóm/Nhân xác nhận quy trình trước thiết kế migration. |
| Slot sau member hủy, PT hủy, hoàn thành | Chưa có luồng ghi Java; không đủ bằng chứng chốt AVAILABLE/DISABLED/BOOKED. Hỏi nhóm nghiệp vụ và người phụ trách PT. |
| Membership hợp lệ để đặt lịch | Chưa có booking write; điều kiện và thời điểm kiểm tra cần xác nhận. |
| Policy, giới hạn và deadline | V4 có bảng `booking_policy` với max advance, min notice, cancellation deadline, max future; chưa có API/service áp dụng. Giá trị và ngoại lệ chờ duyệt. |
| Activation, renewal và thanh toán tại quầy | V2 mô tả membership một dòng và payment; V7 nhánh riêng đề xuất periods và xác nhận tại quầy. Chưa xác nhận yêu cầu, tính idempotent, lịch sử và phương án chuyển đổi; trao đổi Nhân và phụ trách database. |
| PENDING_ACTIVATION, SUSPENDED, CANCELLED | Có trong V2; service đọc chỉ tính lại trạng thái hiển thị của ACTIVE theo ngày, không tự tái kích hoạt trạng thái khác. Quy trình thay đổi cần quyết định. |
| Face ID | V3 có schema; chưa xác minh tích hợp backend, phụ thuộc module Face và quyết định bảo vệ dữ liệu; trao đổi Duy hoặc người phụ trách để xác nhận vai trò. |

Các kết luận về danh tính, constraint và cách đọc hiện tại là hành vi source đã xác minh, không suy ra mọi quy tắc nghiệp vụ đã được nhóm phê duyệt. Chưa có SRS đầy đủ được đối chiếu; nội dung “có trong SRS nhưng chưa triển khai” hiện **chưa đủ bằng chứng**.

## Sổ quyết định mở

Các lựa chọn sau chỉ để thảo luận; nhóm nghiệp vụ cùng chủ module quyết định, không mặc định áp dụng.

| ID / mô tả | Bằng chứng và quyết định đã thấy | Lựa chọn cần xác nhận; người xác nhận | Task ảnh hưởng; tiêu chí đóng |
|---|---|---|---|
| OPEN-BKG-01: xác nhận ngay hay PT duyệt | V4 chỉ CONFIRMED/CANCELLED/COMPLETED; chưa có write | Immediate hay pending/reject; Nhân và chủ PT | R03/R04; có quyết định, state machine và schema được duyệt |
| OPEN-BKG-02: vòng đời slot | V4 có AVAILABLE/BOOKED/DISABLED, không tự đồng bộ | Slot sau member hủy, PT hủy, hoàn thành; nhóm PT | R02/R03/R05; bảng chuyển trạng thái và test đồng thời được duyệt |
| OPEN-BKG-03: điều kiện membership | Đọc booking không kiểm membership; chưa có write | Trạng thái/ngày và thời điểm kiểm tra; nhóm membership | R03; quy tắc và ví dụ ranh giới được chấp nhận |
| OPEN-POL-01: policy hiệu lực | V4 có active, effective_from, unique một active | Policy tương lai và không có policy trả gì; Nhân/chủ nghiệp vụ | R01/R03/R05; contract, timezone, quyền và trường hợp rỗng được duyệt |
| OPEN-MEM-01: activation | V2 cho PENDING_ACTIVATION, V7 đề xuất tại quầy | Chứng từ, số tiền và quyền xác nhận; Nhân và nhóm database | R06; quy trình và trách nhiệm được duyệt |
| OPEN-MEM-02: renewal | Comment V2 cập nhật dòng, V7 đề xuất periods | Cách nối kỳ, thanh toán trùng và quá hạn; nhóm membership/payment | R06/R07; trạng thái, transaction và ví dụ được duyệt |
| OPEN-DB-01: an toàn V7 | V7 xóa cột period trong payment, chưa thấy backfill | Bảo toàn, đối soát và rollback; nhóm database/Nhân | R06/R07; thử migration trên dữ liệu đại diện và chứng minh bảo toàn trước phê duyệt |
| OPEN-FACE-01: Face ID | V3 có facial_profiles/attendance, không có Java API tương ứng | Dependency và quyền riêng tư; Duy hoặc chủ Face | R08; contract và yêu cầu dữ liệu được xác nhận |

Chưa có tài liệu SRS/UC/BR chính thức được xác minh; mã tham chiếu trong migration không đủ để suy ra nội dung yêu cầu.
