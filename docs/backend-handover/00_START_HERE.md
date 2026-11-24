# Bàn giao Backend FitCenter

FitCenter quản lý hội viên và lịch huấn luyện viên cá nhân. Bộ tài liệu này mô tả snapshot đọc ngày 18/11/2026 để người tiếp nhận thiết lập môi trường riêng và tiếp tục công việc; đây không phải phê duyệt nghiệp vụ mới.

Source dùng Java 21, Spring Boot 4.1.1 và PostgreSQL; kiểm thử lịch sử Task 04 dùng PostgreSQL 17.11. Bộ tài liệu vẫn cần hoàn thiện trước khi bàn giao chính thức: OpenAPI là bản nháp, audit chưa đầy đủ; các script mới chỉ được rà soát tĩnh, chưa chạy và còn giới hạn an toàn cần xử lý.

Repository: https://github.com/ThNhan311/Mat_troi_nho_nho. Nhánh local `feature/backend-pt-booking`, HEAD source `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`, chưa có upstream. Kiểm tra GitHub trực tiếp ngày 18/11/2026 không thấy nhánh này; cần công bố trước khi người nhận checkout. Commit tài liệu sẽ có SHA riêng sau khi được tạo. Đọc [hiện trạng](01_BACKEND_CURRENT_STATUS.md) trước khi công bố.

Đã có đăng nhập/refresh, đọc gói và membership, danh mục PT, slot và lịch booking theo danh tính. Chưa có luồng tạo/hủy booking, quản lý slot, kích hoạt/gia hạn hoặc thanh toán. Có schema không đồng nghĩa có API.

Thứ tự đọc: [hiện trạng](01_BACKEND_CURRENT_STATUS.md), [kiến trúc](02_BACKEND_ARCHITECTURE.md), [cài đặt](03_LOCAL_SETUP_GUIDE.md), [database](04_DATABASE_GUIDE.md), [API](05_API_DOCUMENTATION.md), [kiểm thử](06_TESTING_GUIDE.md), [nghiệp vụ](07_BUSINESS_RULES_AND_BLOCKERS.md), [lộ trình](08_DEVELOPMENT_ROADMAP.md), [vấn đề](09_KNOWN_ISSUES.md), [prompt tiếp tục](10_CODEX_CONTINUATION_PROMPT.md), [checklist](11_HANDOVER_CHECKLIST.md).

Quick start: sau khi branch được công bố, làm theo [hướng dẫn thủ công](12_MANUAL_QUICKSTART.md) và đọc [việc tiếp theo](13_NEXT_DEVELOPER_TASKS.md). Không dùng profile `alignment` vì mặc định trỏ tới database được bảo vệ. Flyway tự chạy khi ứng dụng khởi động: xác minh URL trước khi chạy. V7 ở worktree database riêng chưa được tích hợp, có rủi ro lịch sử thanh toán.

## Ngày đầu tiếp nhận

Đối chiếu commit với người bàn giao, đọc [setup thủ công](12_MANUAL_QUICKSTART.md), [API](05_API_DOCUMENTATION.md), [test](06_TESTING_GUIDE.md) và [blocker](07_BUSINESS_RULES_AND_BLOCKERS.md). Trước khi viết code, kiểm tra status/worktree, đọc source và migration liên quan, xác nhận task và quy tắc với nhóm, chuẩn bị DB test riêng. Automation được hoãn; các script nháp bị chặn không thuộc bộ công bố mặc định, xem [trạng thái](scripts/README.md). Người nhận cần tự xác nhận backend chạy được trên máy mình.

M-05/M-06 renewal/simulator (guarded/default-off): [quickstart](21_RENEWAL_SIMULATOR_QUICKSTART.md), [contract](decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md), [evidence](evidence/M05_M06_RENEWAL_SIMULATOR.md). Không dùng số I01 làm kết quả lượt này.

F-01 Core check-in/history: [contract](decisions/2026-11-24_F01_CHECKIN_CORE.md), [OpenAPI](api/openapi.yaml), [quickstart](22_CHECKIN_CORE_QUICKSTART.md), [evidence](evidence/F01_CHECKIN_CORE.md). Adapter identity chỉ simulated/test guarded default-off; không Face ID/liveness E2E.

F02: [evidence](evidence/F02_FACE_ENROLLMENT.md), [quickstart](23_FACE_ENROLLMENT_QUICKSTART.md), [contract](decisions/2026-11-24_F02_FACE_ENROLLMENT.md). Lifecycle simulated đã test, Face thật chưa đạt.

## F03A — private Face Service/evaluation

[Contract/giới hạn](decisions/2026-11-24_F03A_FACE_SERVICE.md), [quickstart](24_FACE_SERVICE_QUICKSTART.md), [evidence](evidence/F03A_FACE_SERVICE.md), [private service OpenAPI](../../face/service_v2/openapi.json). Không endpoint public mới, không đổi default gates/migrations; actual PAD/accuracy/camera chưa được kiểm chứng.
