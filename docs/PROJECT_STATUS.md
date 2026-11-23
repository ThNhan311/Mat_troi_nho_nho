# FitCenter — trạng thái tiếp tục

Cập nhật23/11/2026 tại worktree **Mat_troi_nho_nho-booking-integration**, branch **feature/admin-membership-initial-activation**, base/HEAD trước commit M-03 **92328e0b6a81134921e77e6545b2d5bc02d6d622**. Xác minh Git thực tế khi tiếp tục; commit M-03 ghi trong Git history, không tự tham chiếu SHA của chính file này.

## M-03 đã triển khai và kiểm chứng trên rehearsal riêng

Admin UI gốc Home→Kích hoạt Gói hội viên, tách tạo account. POST initial activation và GET committed receipt reconcile; server Clock ngày VN inclusive, ACTIVE plan price/duration snapshot, receipt unique/idempotency, atomic Membership/payment COUNTER SUCCESS/audit, Member-first lock và DB constraints. Không đổi User/password/JWT, không renewal/gateway/Booking. M-04 đọc cùng UUID/date sau reload/login. [Quyết định/contract](backend-handover/decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md), [API/OpenAPI](backend-handover/05_API_DOCUMENTATION.md), [evidence/hashes/ảnh](backend-handover/evidence/M03_INITIAL_MEMBERSHIP.md), [quickstart](backend-handover/18_INITIAL_MEMBERSHIP_QUICKSTART.md).

Thực chạy Backend **832 passed/0failed/0errors/0skipped** trong scoped full regression; focused62 là tập con. Không chọn2 PostgreSQL PT-rehearsal suites để không làm lại task đã đóng; PT unit/mail tests vẫn chạy. Admin **89 passed**, Member **53 passed**,0failed/skipped. Analyze0error/0warning, còn Admin65/Member44info; `--no-fatal-infos` exit0, không strict lint clean. JS web build cả hai đạt; PT Dart không đổi, không lặp PT build/tests.

Chrome UI **24**, HTTP riêng **3**, PostgreSQL **5** checks đạt, không cộng vào tests. UI tạo Membership/payment thật giá0/30ngày, Admin reload đọc snapshot, Member ACTIVE fixture reload/login M-04 cùng UUID, duplicate receipt409 không tạo thêm; account/Booking/legacy rows không mutation. MEMBER ACTIVE là fixture, không chứng minh MEMBER activation. Schema V9 đã kiểm DB trống và1–6 có6payments nhiều trạng thái/NULL link, snapshot giữ nguyên periods/data. Cleanup exact UUID trên8 DB task,24checks, chạy lại vẫn đạt; dừng own backend/web/container, ports3000/3002/18083/15440 đóng, giữ volume;2container ngoài task không sửa.

## Git/scope và phát hành

M-03 Java/Dart/test/helpers/schema rehearsal/docs/ảnh được review, commit/push nhánh riêng theo quyền người dùng, không merge/force. Bốn research22/11 untracked được giữ ngoài commit, Face checkout gốc089b5e2 không đụng. Credentials/manifest/raw logs/SDK/cache/build ngoài Git. Fetch database ref **558fb03** không đổi. Kiểm remote23/11:0workflows/runs/deployments/webhooks, không gọi là CI pass.

Default M-03 **false/503**. V9 chỉ `db/membership-rehearsal`, profile membership-rehearsal guard loopback15440/app-role/tên DB/location; PT activation vẫnfalse, V8 location riêng giữ nguyên. History1–6,9 và1–6,8 **không phải release**. Không applyV7/out-of-order/history edit/clean/repair. Blocker release: thống nhất V7/V8/V9 version/order và sửa hướng V7 DROP periods chưa backfill với Duy, phân loại COUNTER initial có transaction. Không còn blocker cho rehearsal M-03 đã kiểm chứng; chưa rollout DB chung/production.

Bước tiếp theo: review nhánh M-03; đồng bộ chuỗi migration bảo toàn lịch sử trước merge/release. MEMBER email→OTP→password đã được đồng ý là **task riêng**, chưa triển khai ở M-03. Renewal/refund/gateway/plan update/status/delete/Face/Workout vẫn ngoài phạm vi.

## Mốc đã đóng

M-04 **92328e0** ([evidence](backend-handover/evidence/M04_MEMBER_MEMBERSHIP.md)); PT activation rehearsal **0c31947** ([evidence](backend-handover/evidence/PT_ACTIVATION_POSTGRES.md)), default vẫnfalse/503; M-01 **6fbf9fc**, account/PT core **66a7031**. Các số test trong báo cáo mốc cũ là lịch sử, không phải lần chạy mới. [AGENTS](../AGENTS.md), [DECISIONS](DECISIONS.md).
