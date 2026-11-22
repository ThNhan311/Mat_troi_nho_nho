# FitCenter — trạng thái tiếp tục

Cập nhật22/11/2026 tại worktree **Mat_troi_nho_nho-booking-integration**, branch **feature/pt-activation-postgres-rehearsal**, HEAD lúc ghi **66a70311517ccd0bf287eff45b476f1ce5138a16** (source base; commit bàn giao tiếp theo chứa tài liệu này). Luôn xác minh Git khi tiếp tục.

## Task đã kiểm chứng

Quyền mới cho phép tự hoàn thiện/apply schema trên DB test riêng, không chờ Duy; không DB chung/production. Thêm **V8__pt_account_activation.sql** tại location rehearsal riêng, canonical V1–V6 giữ nguyên, không áp V7. Profile mặc định vẫn activation=false/503; profile activation-rehearsal bật riêng sau pre-Flyway datasource/role/location guard. [Quyết định/version/order](backend-handover/decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md).

**Full Backend801 passed,0failed/errors/skipped**, focused65 là tập con. Schema10/HTTP20/guard9 mới đã nằm trong801. Thực sự kiểm DB trống và DB V1–V6 có lịch sử tổng hợp, giữ dữ liệu/periods, constraints, lateV7 refusal, rollback DDL; HTTP+PostgreSQL+SMTP/Clock/concurrency lock thật. Hai Web build đạt với baseURL18082; không sửa Dart nên không lặp widget/analyze hoặc tính counts cũ thành mới.

**Lát cắt E2E PT activation trên rehearsal đã đạt:** Admin UI tạo DISABLED → email/SMTP loopback → OTP → password → ACTIVE → PT login/re-login.13UI checks,4HTTP riêng,DBaudit4; không cộng vào tests. Không gửi mail người thật hoặc log secret. [Evidence/hashes/checks](backend-handover/evidence/PT_ACTIVATION_POSTGRES.md), [quickstart](backend-handover/16_PT_ACTIVATION_REHEARSAL_QUICKSTART.md).

## Git và môi trường

M-01/account đã có trên remote tại6fbf9fc/66a7031; task mới sẽ commit/push nhánh riêng sau review, không merge/force-push. Bốn research untracked giữ nguyên ngoài scope; các links research dùng local đến khi xuất bản riêng. Face ở checkout gốc089b5e2 không sửa. Không build/cache/SDK/credential/manifest/raw logs vào Git.

Container rehearsal riêng3861f4dd…/volume fitcenter_activation_20261122_data/loopback15439; mỗi run hai DB mới. UI account và fixture3run thành công đã cleanup theo UUID hai lần. Node/Java/wrapper/SMTP/container task đều dừng; baseline full runner cũng dừng, giữ volumes. Không thay DB chung/production hoặc Clock production.

## Còn cần đồng bộ trước merge/release

Ref database558fb03 có V7 membership periods; V7 thật chỉ resolve/validate, chưa execute. V8 rehearsal sau1–6 khiến V7 đến sau bị từ chối. Cần đồng bộ Duy về canonical path/version/checksum và order; rehearsal release lại trên DB mới theo thứ tự đã chốt, không out-of-order/history edits. V7 DROP payment period chưa backfill vẫn là rủi ro riêng. Đây là giới hạn release, không còn blocker cho kiểm thử riêng đã hoàn thành.

Default production gate503, production SMTP, MEMBER activation, Membership/Payment/Workout/Face chưa mở rộng trong task. Tiếp theo review/publish commit hiện tại rồi lập release sequencing với Duy. [AGENTS](../AGENTS.md), [DECISIONS](DECISIONS.md).
