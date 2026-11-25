# FitCenter — Core Backend và Flutter Web

[Trạng thái hiện tại](docs/PROJECT_STATUS.md) · [Setup/demo tích hợp](docs/INTEGRATION_SETUP.md) · [Quyết định nghiệp vụ](docs/DECISIONS.md) · [API](docs/backend-handover/05_API_DOCUMENTATION.md)

Ba app Web giữ giao diện gốc: Member, PT và Admin. Đã có các lát cắt Account activation, Membership Plan/initial activation/read/renewal simulator và Booking. Đây chưa phải toàn bộ FitCenter hoặc một bản phát hành production.

| App | Source | Origin demo |
|---|---|---|
| Member | [fitcenter_member](frontend/fitcenter_member/) | http://localhost:3000 |
| PT | [fitcenter_pt](frontend/fitcenter_pt/) | http://localhost:3001 |
| Admin | [fitcenter_ad](frontend/fitcenter_ad/) | http://localhost:3002 |

Bắt đầu bằng [hướng dẫn portable](docs/INTEGRATION_SETUP.md). Entrypoint hiện hành là [core-readiness.ps1](backend/scripts/core-readiness.ps1), tạo DB test và authority mới trên máy đích. Không cần container ID, credentials, DPAPI hoặc build của người phát triển trước. Guard cố định Docker Desktop Linux local, JDK21, image17.12 ghim và loopback ports; không bypass khi có collision.

Default Backend chỉ dùng canonical V1–V6. Account/Membership write mới và simulator chỉ bật trong guarded rehearsal; chuỗi V1–V6,V8–V13 chưa là release migration. V7 của nhánh Database chưa có backfill an toàn và DB chung chưa được inventory: **releaseReady=false**. Xem [fresh install/upgrade](docs/INTEGRATION_SETUP.md#fresh-install-và-upgrade).

Simulator là thanh toán mô phỏng dev/test, không tiền thật/gateway/refund. Face Core/enrollment/service chỉ có simulated protocol và generated-input inference evidence; **Face thật chưa nghiệm thu**. F03B tooling ready, thu ảnh/dataset/calibration/evaluation người thật đang hoãn, liveness NOT_PERFORMED/admission thật off. Workout, thông báo, profile editing, full Admin reporting và native/mobile không thuộc lát cắt Web đã nghiệm thu; UI chưa có API hiện Chưa khả dụng.

Không đưa `.env`, authority/credential/consent, dataset/ảnh/embedding, SDK/cache/build hoặc raw logs vào Git. Không dùng clean/repair/out-of-order, không sửa migration đã công bố, không thay DB chung. [AGENTS](AGENTS.md) dành cho agent tiếp tục; [R01 readiness](docs/backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md) là snapshot trước sửa R02.

R02 đã kiểm chứng portable rehearsal từ checkout sạch có dùng cache: [kết quả, suites và giới hạn](docs/backend-handover/evidence/R02_PORTABLE_SETUP.md). Đây không phải cold install hoặc xác nhận production release.
