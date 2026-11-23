# FitCenter — trạng thái tiếp tục

Cập nhật23/11/2026 tại worktree **Mat_troi_nho_nho-booking-integration**, branch **feature/member-membership-read**, HEAD lúc ghi **0c31947b60bacbb7d7516556a7f2b44193ec86a8** (source base; commit M-04 tiếp theo chứa tài liệu này). Xác minh Git khi tiếp tục; snapshot không thay thế branch/HEAD thực tế.

## Task M-04 đã kiểm chứng

Member Login/Home/navigation gốc → Gói hội viên nối GET `/api/v1/memberships/me`. Array UUID/planName/startDate/endDate/status, hiển thị mọi bản ghi không suy phần tử đầu là current/next; DATE giữ lịch Việt Nam, status do Backend tính. Loading/empty/error, refresh giới hạn/session epoch loại response cũ; gia hạn/thanh toán Chưa khả dụng. Không price/paidAt/history giả. [Evidence/hashes/ảnh](backend-handover/evidence/M04_MEMBER_MEMBERSHIP.md), [quickstart](backend-handover/17_MEMBER_MEMBERSHIP_READ_QUICKSTART.md).

Thực chạy **Member52 passed/0failed/0skipped**, focused15 là tập con. Analyze `--no-fatal-infos` exit0,0error/0warning/44info Material/style (strict trước đó exit1); JS Web build passed. **Chrome UI19, HTTP14, PostgreSQLaudit10 checks**, cleanup4 checks chạy lại cũng đạt; không cộng vào tests. Reload/login cùng UUID/date/status DB, MemberB empty không lộ A;7status/date cases, GET không mutation dữ liệu ngoài scenario. Lỗi tool path/viewport đã sửa và UI cuối chạy lại. Không sửa executable Backend/shared Admin/PT, không lặp801 Backend hoặc activation.

## Git và tài nguyên

Task M-04 chỉ Member Dart/test, helper UI/DB và docs/evidence, sẽ commit/push nhánh riêng sau review theo quyền đã giao; không merge/force-push. Bốn research untracked giữ nguyên ngoài scope. Face ở checkout gốc089b5e2 không sửa. Không SDK/cache/build/credentials/private manifest/raw logs staged. CI/CD kiểm qua remote trước push:0workflows/runs/deployments/webhooks, không tracked CI/non-sample Git hooks; không gọi đó là CI pass.

Dùng DB baseline riêng V1–V6/container e4c5299f…/volume fitcenter_baseline_20261120_data/loopback15437, JDK21/default profile. Fixture MEMBER ACTIVE là SQL tổng hợp, không MEMBER activation. Scenario restore exact UUID/snapshot rồi base fixture cleanup; own backend/web/container đã dừng, ports3000/18081/15437 đóng, giữ volume. Docker Desktop còn chạy vì containers ngoài task, không dừng/sửa chúng. Không DB chung/production.

## Các mốc trước và giới hạn còn lại

[PT activation rehearsal](backend-handover/evidence/PT_ACTIVATION_POSTGRES.md) đã hoàn thành tại **0c31947**: Backend801 và E2E riêng là evidence lịch sử, không phải lượt M-04. Không làm lại rehearsal/bật activation mặc định; default false/503 vẫn giữ. V8 ở location riêng, chưa canonical/release; cần đồng bộ version/order với V7 của Duy trước merge/release, không out-of-order/history edits. [Quyết định](backend-handover/decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md).

M-01 đã đóng6fbf9fc, account/PT core66a7031. MEMBER activation, initial membership activation, renewal/payment, current/next periods/history, Face/Workout chưa triển khai trong M-04. Không coi list Membership là hoàn tất module Membership/Payment. Không có blocker cho read UI; bước tiếp theo review/publish M-04, chọn lát cắt initial activation/Member account theo [khảo sát](backend-handover/research/2026-11-22_CORE_MEMBERSHIP_PAYMENT_SURVEY.md) và quyết định nghiệp vụ còn mở. [AGENTS](../AGENTS.md), [DECISIONS](DECISIONS.md).
