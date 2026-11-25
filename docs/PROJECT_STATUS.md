# FitCenter — trạng thái sau merge PR #8

Cập nhật25/11/2026: source main/merge commit **5259f51c967994c85dcd0ff54512d15ce0e52c9e**. [PR #8](https://github.com/ThNhan311/Mat_troi_nho_nho/pull/8) **merged=true**, method=merge với expected HEADf0cb793; parents5c8693b vàf0cb793. Tree/390source blobs/14SQL hashes khớp ứng viên đã duyệt. Nhánh chức năng còn nguyên, worktree cũ được bảo toàn. Người dùng chỉ cho mergePR8 trong scope fresh Web Core demo; **không deploy/DB chung hoặc merge thêm**.

Báo cáo này trên branch **verification/pr8-postmerge-smoke** từ clean main5259f51, chỉ docs/evidence/status; Git là HEAD publication thực tế. [Post-merge evidence](backend-handover/evidence/PR8_POST_MERGE_SMOKE.md), [JSON](backend-handover/evidence/PR8_POST_MERGE_SMOKE_RESULTS.json). Không ghi thêm commit trực tiếp vào main.

Smoke mới sau merge đạt **26UI/29HTTP/9DB checks**,0failed/skipped, cùng Backend/DB/mail. Admin-only seed→plan/accounts/M03→OTP Member/PT→ACTIVE/login→M04→slot→Booking/cancel/rebook/readUUID/reload.3gate checks mới đạt: Admin login/Face503/dev-test simulator GETempty. Backend package và3Webbuild mới đạt, cache dùng/không cold install; **không rerun full1118/unit/widget/analyze** vì executable không đổi.0workflow/status/check-run trước merge không phải CI pass.

Fresh JAR exactV1–V6,V8–V13, không V7/V14/callback; core-demo Face4gates=false, simulator dev/test/ADMIN. [Setup](INTEGRATION_SETUP.md), [quyết định](DECISIONS.md), [upgrade](DB01_UPGRADE.md). Canonical paid periods/M03receipt/snapshots/ownership giữ nguyên. CleanupUUID2lần/stop đúng2container+process, giữvolume;4research untracked/26Face nguyênhashes. Không cần bản sửa do smoke đạt.

Giới hạn: Face accuracy/PAD/camera-to-admission người thật chưa nghiệm thu; dataset/calibration/evaluation hoãn, NOT_PERFORMED/admission off. targetUpgradeVerified=false, chưa gateway/refund/production rollout/DB cũ thực tế. Các kết quả1118Backend, Flutter80/55/133 vàDB01-196 trong [candidate evidence](backend-handover/evidence/CORE_MAIN_CANDIDATE.md) là lượt trước, không vừa chạy lại. Tiếp theo người dùng quyết định task mới; không tự deploy/nâng DB chung.
