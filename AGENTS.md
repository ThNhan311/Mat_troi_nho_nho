# FitCenter — hướng dẫn tiếp tục

- Đọc [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) và [docs/DECISIONS.md](docs/DECISIONS.md) trước, rồi chỉ mở tài liệu chi tiết liên quan. Xác minh branch/HEAD/status/worktrees; status là snapshot, Git là thực tế.
- Bảo toàn working tree ngoài task, nhất là Face, tài liệu khảo sát và phần công việc chưa commit. Không reset/stash/tự merge/git add .; không commit/push/merge nếu chưa được giao.
- Canonical SQL ở database/migrations, hiện V1–V6. Không sửa migration đã áp; V7 của Duy ở ref database phải được đối chiếu. SQL đề xuất dưới docs không phải migration được phép chạy. Không clean/repair/alignment hoặc onboarding BLOCKED.
- Java dùng JDK21; DB riêng qua backend/scripts/test-http-baseline.ps1 hoặc booking-demo.ps1 với containerID/volume/port/role/history đã xác minh trước Flyway. Không DB dùng chung/LAN/firewall. Cleanup theo đúng UUID; stop đúng tài nguyên tự tạo, giữ volume.
- Giữ UI/theme/navigation gốc. API DTO/UUID/time server, không mock fallback/fake success. Token memory, epoch loại response/modal cũ, không replay write chưa rõ kết quả.
- Không lưu/log password, OTP, token, credential/manifest/raw logs/SDK/cache/build vào Git hoặc docs. Mail chỉ test loopback và địa chỉ tổng hợp khi chưa triển khai adapter production.
- Chạy focused khi sửa, regression phù hợp trước bàn giao; không cộng focused với full hoặc HTTP/DB/UI checks. Evidence phải gắn source hashes. Không gọi kết quả lịch sử là vừa chạy.
- Cập nhật PROJECT_STATUS trước kết thúc; ghi blocker chính xác và phần chưa kiểm chứng. Không tự mở rộng Membership/Payment/Face/Workout.

- Quyền mới22/11: được rehearsal schema OTP trên DB test riêng đã guard, không chờ Duy. V8 activation ở location riêng, không Flyway mặc định; không áp V7/out-of-order/history edits. Đồng bộ version/order trước merge/release. Commit/push nhánh chức năng được phép sau review, không merge.

## Learnings

- Runner Java/PostgreSQL phải cố định JVM UTC; alias Asia/Saigon từ Windows có thể bị image PostgreSQL từ chối. PowerShell5 có thể coi native stderr của JAVA_TOOL_OPTIONS là lỗi terminating: chỉ đổi ErrorActionPreference quanh lệnh native rồi kiểm exit code/fresh reports, không bỏ kiểm lỗi.
- Guard JDBC URL bằng URI host/port/path và identity DB/role thật; PGSimpleDataSource có thể thêm query suffix. Migration rehearsal phải ở location riêng khi chưa bảo đảm thứ tự canonical; V8 trước V7 không được chữa bằng out-of-order/history edits. Xem [quickstart](docs/backend-handover/16_PT_ACTIVATION_REHEARSAL_QUICKSTART.md).

- M-03 rehearsal: V9 location riêng/default-off, chỉ runner membership-rehearsal guard DB loopback15440; không áp V7/V8 vào DB này hoặc coi history1–6,9 là release. Initial Membership không ACTIVE hóa User. [Quyết định](docs/backend-handover/decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md), [chạy lại](docs/backend-handover/18_INITIAL_MEMBERSHIP_QUICKSTART.md).

- MEMBER activation: V10 riêng, integrated profile guard15441/locations1–6,8,9,10; không ghép profiles rehearsal cũ hoặc tắt guard. OTP User→role-state, không Membership/payment mutation. [Contract](docs/backend-handover/decisions/2026-11-23_MEMBER_ACCOUNT_ACTIVATION.md), [quickstart](docs/backend-handover/19_MEMBER_ACCOUNT_ACTIVATION_QUICKSTART.md). Private fixture registry đặt ngoài sandbox phiên dễ bị dọn; nếu mất authority thì verify resource/namespace trước recovery, không reset DB. PowerShell5 Set-Content UTF8 thêm BOM: Java source/JSON dùng UTF8 không BOM, npm.cmd tránh ExecutionPolicy của npm.ps1.

- I-01: frozen candidate + runner riêng, default gates giữ nguyên; gap7/shared inventory chưa biết nên không release-ready. E2E Admin-only dùng DB pair mới, mọi đối tượng nghiệp vụ qua API/UI. [Quickstart](docs/backend-handover/20_CORE_INTEGRATION_QUICKSTART.md). PowerShell5 serialize collection cần kiểm structure; log *> có thể UTF16.

- M05/M06: renewal V11 location riêng/default-off; profile renewal-integration-rehearsal guard15441, không ghép profile cũ hoặc áp V7. Member→Membership→payment/quote→event claim; paid periods giữ current/next/history, không ghi đè plan tương lai. [Quyết định](docs/backend-handover/decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md). Khi pipe Unicode qua Python trên PowerShell5 đặt OutputEncoding=UTF8 và ghi UTF8 không BOM; không sửa SQL đã áp. Cleanup nhiều UUID gửi SQL qua stdin tránh giới hạn command line Windows.

- F01: source Face nhận diện hiện có ở origin/feature/face-1n-identification pinfcabeba; checkout gốc chỉ untracked caches/model/venv, không overwrite/decompile. Core dùng opaque captureRef + service credential; test identity SIMULATED_TEST/default-off, không Member tự khai match. [Contract/khóa/quickstart](docs/backend-handover/decisions/2026-11-24_F01_CHECKIN_CORE.md). Export source pin private, PYTHONDONTWRITEBYTECODE/pytest cache off khi kiểm protocol; chờ cleanup lặp xong mới stop DB.

- F02: enrollment V13/profile face-enrollment-rehearsal default-off; Member→operation→profile, external prepare/remove ngoài DB transaction. Adapter journal SIMULATED_TEST, không ghi đè Face/model hoặc coi NOT_PERFORMED là liveness. [Contract/recovery](docs/backend-handover/decisions/2026-11-24_F02_FACE_ENROLLMENT.md). Legacy reference thiếu managed owner phải manual; không xóa dựa vào prefix.

- F03A: remote HTTP adapter chỉ trong guarded F02 rehearsal; V13 vẫn SIMULATED_TEST, actual model provenance/NOT_PERFORMED không admission. Source dependency Face import nguyên pinfcabeba; private runtime/model/dataset ngoài Git. [Service/evaluation quickstart](docs/backend-handover/24_FACE_SERVICE_QUICKSTART.md), không gọi protocol/tensor smoke là biometric accuracy/camera/PAD.

- F03B: capture chỉ terminal tương tác/consent/R+Space từng ảnh; dataset/consent/scores ngoài mọi Git worktree. Gallery/probe khác phiên, calibration/evaluation khác người; seal→calibrate→freeze→evaluate, không tune trên evaluation. [Operator quickstart](docs/backend-handover/25_FACE_CAMERA_EVALUATION_QUICKSTART.md). Camera IOprobe và generated-input tests không phải accuracy/PAD; admission/default gates giữ nguyên.

- R02 portable Core: [setup hiện hành](docs/INTEGRATION_SETUP.md), `backend/scripts/core-readiness.ps1` tạo namespace/credentials/authority mới từ image lock17.12. Runner lịch sử phải pin đúng commit; không nới exact migration inventory khi có SQL mới. Manifest/resources ngoài Git, fullID/image/context/volume/port/DB/role/history guards giữ nguyên; schema release vẫn chưa chốt do V7/shared inventory. Native stderr JVM trên PowerShell5 chỉ đổi ErrorActionPreference quanh lời gọi rồi kiểm exit code/fresh reports.

- DB01 chỉ candidate test: [hai đường/inventory](docs/DB01_UPGRADE.md). V14 một mình sau V11 không sửa được thiếu payment columns; cần compatibility trước dependency. Published V1–V13 giữ nguyên, default locations/gates không đổi; shared inventory/version14/consumer legacy và M04 name fallback vẫn release blockers. Không chạy candidate lên DB chung từ README; fresh test phải guard/authority mới, cleanup theo sealed PK.
