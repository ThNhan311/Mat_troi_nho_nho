# FitCenter — trạng thái tiếp tục

Cập nhật23/11/2026 tại worktree Mat_troi_nho_nho-booking-integration, branch **feature/core-integration-rehearsal**, base/HEAD trước commit **950311082d4cc5b2c5b85b1a3f8cd644246cd932** (MEMBER activation). Xác minh Git khi tiếp tục; commit đóng I-01 tra history, không tự tham chiếu SHA của chính file này.

## I-01 đã kiểm chứng rehearsal

Frozen manifest/version/path/SHA-256/FlywayCRC32 và runner fail-closed cho **V1–V6,V8,V9,V10**, V7 database558fb03 quarantined. Không đổi SQL/version/schema sản phẩm, default gates hoặc source Java/Dart sản phẩm. Upgrade DB trống và dữ liệu lịch sử tổng hợp:1–6→8/9→10, snapshots giữ nguyên payment periods/status/null, PT state, M03 receipt/audit/idempotency/price-duration snapshots. Validate-only đưa V7late thất bại không chạyDDL. Shared inventory **chưa biết**, không giả định DB đồng đội chưa ápV7; **releaseReady=false**.

Thực chạy scoped full **918 passed/0failed/0errors/0skipped**,33XMLsuites tươi. Focused163 là tập con. Không chọn3lớp PG profile cũ, đã có integrated counterparts; chi tiết selector trong evidence. Flutter Web build cả3app cùngAPI18084 đạt; không sửa Dart nên không rerun widget/analyze và không lấy kết quả lịch sử làm lượt mới.

E2E mới **26UI/29HTTP/9DB checks**,0failed/skipped: cùngbackend18084/DB15441/mail sink. Chỉ seedAdmin; Admin UI tạo plan, HTTP tạo DISABLEDMember/PT A/B và M03 thuquầy +policy; Member/PT A kích hoạt OTP/password qua UI gốc, B quaHTTP+SMTP; Member M04→PT UI slot→Member UI CONFIRMED→cancel→AVAILABLE→hành động mới rebook/newUUID→reload/login; PT đọc cùngUUID/time. Ownership/role và payment/Membership snapshots giữ nguyên. Ba lỗi helper UI trước đã sửa/cleanup rồi chạy lại toàn bộ pair mới, không phải lỗi production code.

[Evidence/hashes/ảnh](backend-handover/evidence/I01_CORE_INTEGRATION.md), [quickstart tích hợp](backend-handover/20_CORE_INTEGRATION_QUICKSTART.md), [inventory/chuỗi ứng viên/release gates](backend-handover/decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md).

## Git và tài nguyên

Review để commit/push nhánh riêng theo quyền người dùng, không merge/force. Thay đổi task chỉ runner/test/helper/manifest/docs/evidence; không migration áp dụng hoặc code sản phẩm. Bốn research22/11 untracked giữ ngoài commit; Face và survey untracked checkout gốc089b5e2 nguyên vẹn. Credentials/OTP/grant/token/private manifests/raw logs/tools/build ngoài Git. Remote23/11 không workflow/run/deployment/webhook; không gọi CI pass.

Cleanup exactUUID trên10DB của5pair task,30checks, lặp lại đạt; ngoài fixture không đổi, giữ schema/history/volume. Đã dừng ownbackend/wrappers/3web/mail và DB test; task ports đóng, volume account/baseline còn. Không DB chung/production/Docker Desktop/tài nguyên ngoài task bị đổi.

## Blocker phát hành và bước tiếp theo

Cần chủ DB cung cấp actual Flyway inventory/checksum (V7 có thể đã áp), backup/export periods bị DROP, thống nhất mapping initial COUNTER và thứ tự/location/artifact V7–V10. V7 hiện DROP payment periods chưa backfill và khác semantics M03; không chạy nguyên bản. Có phương án release có điều kiện trong decision, chưa là migration được phép apply. Không out-of-order/history edits/clean/repair hoặc đổi số published để lách.

Bước tiếp: review nhánh I-01, thu inventory từ chủDB bằng SQL chỉ đọc được cung cấp, quyết định compatibility/backfill trước canonical release. Production email adapter vẫn chưa có; không tự mở gateway/renewal/Workout/Face. Complete/cancel boundaries có regression, không sửa Clock production để giả hoàn thành tương lai.

## Mốc đã hoàn thành trước I-01

MEMBER activation **9503110**, M-03 **5399c57**, M-04 **92328e0**, PT rehearsal **0c31947**, account core **66a7031**, M-01 **6fbf9fc**. [MEMBER activation evidence](backend-handover/evidence/MEMBER_ACCOUNT_ACTIVATION.md), [quyết định tổng hợp](DECISIONS.md), [quy tắc repository](../AGENTS.md). Số914/60/55 và E2E của Member task là lịch sử, không cộng vào I-01.
B? sung review sau checkpoint core **093c593**: pin EOL SQL qua [.gitattributes](../.gitattributes),2checkout experiments (autocrlf true/false,9SQL m?i mode) ??t v? source hashes core v?n kh?p. Kh?ng s?a migration hay rerun full/UI khi executable kh?ng ??i. [Evidence checkout](backend-handover/evidence/I01_CHECKOUT_RESULTS.json).
