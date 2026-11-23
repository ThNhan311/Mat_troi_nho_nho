# FitCenter — trạng thái tiếp tục

Cập nhật23/11/2026 tại worktree Mat_troi_nho_nho-booking-integration, branch **feature/member-account-activation**, base/HEAD trước commit **5399c5707288669997e898740daa36c57d04d632** (M-03). Xác minh Git khi tiếp tục; SHA commit task tra Git history, file không tự tham chiếu SHA của chính nó.

## MEMBER account activation đã triển khai và kiểm chứng rehearsal

Login/theme/navigation Member gốc→email→OTP300s→verify→password→ACTIVE→login. Tái sử dụng core an toàn PT, role/store/challenge/grant riêng, kiểm profile + Admin-created marker; không legacy/suspended/completed reactivation, không normalJWT trướcACTIVE. Không cần Membership, không mutate Membership/payment. M-03 Member-first và activation User-first độc lập; race cả hai commit đúng một lần. [Contract/decisions](backend-handover/decisions/2026-11-23_MEMBER_ACCOUNT_ACTIVATION.md), [evidence/hashes/ảnh](backend-handover/evidence/MEMBER_ACCOUNT_ACTIVATION.md), [quickstart](backend-handover/19_MEMBER_ACCOUNT_ACTIVATION_QUICKSTART.md).

Thực chạy scoped full **914 passed/0failed/0errors/0skipped**, focused159 tập con. PT23 + Member24 HTTP/PG/SMTP cases trên integrated profile; M0354 và schema5 trong cùng full. Không chọn3 PG classes profile riêng cũ (đã có lớp integrated thay thế), không tính chúng là pass. Member Flutter**60 passed**, PT Flutter**55 passed**,0failed/skipped; PT source không đổi. Member analyze0error/0warning/58info, --no-fatal-infos exit0; Member/Admin JS Web build đạt. Admin Dart unchanged, không rerun Admin tests.

E2E Chrome thật **15 UI/5HTTP/3DB checks**: Admin UI tạoMember DISABLED→M03 cấp Membership→Member SMTP loopback OTP/password→ACTIVE→login→M04→reload/login cùngUUID/date. Chỉ Admin vàplan được seed, **không ACTIVE Member fixture để thay activation**. Snapshot Membership/payment/chứng từ/Booking/PT cũ không đổi sau activation. Mail test @example.invalid, chưa production email/E2E toàn hệ thống.

## Database/release

V10 riêng CREATE member_account_activation, không sửa V1–V6/V8/V9 hoặcPT role constraint. Profile account-integration-rehearsal guard trướcFlyway URL127.0.0.1:15441/app-role/tênDB/flag/4locations; migrate1–6,8,9,10, không compose profiles cũ. M03 guard giữ target15440 cũ và thêm nhánh integrated cóguard. Default Member/PT/M03 vẫn false/503. DBtrống và history1–6,8,9 cóPTstate/counterreceipts/payment periods giữ nguyên quaV10.

History gapV7 là rehearsal, **không release**. Blocker rollout: đồng bộ Duy V7/V8/V9/V10 ordering và backfill V7 DROP periods chưa bảo toàn dữ liệu. Không applyV7/out-of-order/history edit/clean/repair, không DBchung/production. Production mail adapter/rate-limit tầng hạ tầng vẫn chưa triển khai; không quảng bá mail thật.

## Git và tài nguyên

Task được review rồi commit/push nhánh riêng theo quyền người dùng, không merge/force. Fetch23/11 database ref558fb03 không đổi; CI/CD remote0workflow/0run/0deployment/0webhook, không gọi là CI pass. Bốn research22/11 untracked giữ nguyên ngoài scope; Face checkout gốc089b5e2 không sửa. Credentials/OTP/grant/token/private manifest/raw logs/tools/build ngoàiGit. Private sandbox cũ mất sau môi trường phiên đổi: own container/namespace/role verified, phục hồi exactUUIDregistry và rotate riêng app test credential, không đổi rows/history. Không lặp914 vì app source không đổi.

Cleanup exactUUID trên6DB task,18checks, chạy lại đạt; dừng ownbackend/web/mail/container/ports, giữ volume fitcenter_account_20261123_data. Hai container ngoài task không đụng. Bước tiếp theo review nhánh và đồng bộ migration release + mail adapter phù hợp; không tự mở rộng renewal/gateway/Face/Workout.

Mốc trước: M-03 **5399c57**, M-04 **92328e0**, PT rehearsal **0c31947**, account core **66a7031**, M-01 **6fbf9fc**. Báo cáo các mốc đó là lịch sử; lần914/60/55 vàE2E ở trên là thực chạy trong task Member này. [AGENTS](../AGENTS.md), [DECISIONS](DECISIONS.md).
