# PR #8 — merge và smoke fresh main,25/11/2026

**PR #8 đã merge; smoke sau merge đạt,0failure/skipped.** [PR](https://github.com/ThNhan311/Mat_troi_nho_nho/pull/8), [merge commit/main](https://github.com/ThNhan311/Mat_troi_nho_nho/commit/5259f51c967994c85dcd0ff54512d15ce0e52c9e), [results/UUID/checks](PR8_POST_MERGE_SMOKE_RESULTS.json). Báo cáo trên nhánh verification/pr8-postmerge-smoke; không thêm commit trực tiếp vào main hoặc merge thêm PR.

## Merge đã xác minh

Reviewed/expected HEAD **f0cb7931f7d5c75c56ab0b0fc69b12e93075decb**; base **5c8693bfaeb4c0e85f4c7bcb21c5fd487dad3516**, không có drift.390/390source blobs và14SQL hashes khớp [evidence](CORE_MAIN_CANDIDATE_RESULTS.json). GitHub ready/mergeable,0workflow/status/check-run: không CI pass. Connector không có quyền đọc protection metadata (403); dùng normal merge API với expected_head_sha/method=merge, không bypass/force/admin override.

GitHub merged=true, merge commit và remote main **5259f51c967994c85dcd0ff54512d15ce0e52c9e**. Hai parent đúng base cũ và PR HEAD; tree trùng ứng viên. Nhánh release/core-main-candidate vẫn ởf0cb793, không xóa. Worktree tích hợp cũ vẫn ởf0cb793/nhánh đó;4research untracked/26Face ngoài task nguyên hashes.

## Smoke mới thực chạy

Clone mới từ remote main5259f51, source ban đầu sạch, không copy build/credentials/manifest. Provision tạo2container/volume/crypto credentials/authority mới, role/DB/loopback/fullID/image/hash guards; Build/Verify đạt. Dùng JDK21/PostgreSQL17.12 ghim; build mới Backend và3FlutterWeb với API_BASE_URL18086, pub --offline --enforce-lockfile. Cache dependency/image/SDK có sẵn, không cold install.

Re-use [Core harness](../../../frontend/verify-core-integration.mjs) `--current`, [runner](../../../backend/scripts/core-readiness.ps1) theo [setup](../../INTEGRATION_SETUP.md): PrepareDemo Core→ServeBackend/mail sink/3Webservers→harness→Cleanup2lần→Stop. Cùng Backend/DB/mail, Chrome headless thật1024×768/browser America/Los_Angeles, Clock thật. Chỉ seed Admin tổng hợp; business objects qua API/UI thật.

| Scope | Mới chạy sau merge | Giới hạn |
|---|---|---|
| Original UI |**26checks đạt**|Admin login/plan, MEMBER/PT email→SMTP sink→OTP→password→ACTIVE→login, M04, PTslot, Memberbook/cancel/rebook, reload/login2bên. |
| HTTP |**29checks đạt**|Actual API/response UUID/status; owner/role/anonymous/old-cancel409 và cùng Booking UUID/time. |
| PostgreSQL |**9checks đạt**|Admin-only initial state, M03 payment/receipt/Membership unchanged through activation/Booking, slot BOOKED/available/cancel history/rebook đúng owner/time. |
| Gate smoke |**3checks đạt**|Admin login; Face enrollment503 ERR_FACE_ENROLLMENT_UNAVAILABLE; Admin simulator dev/test GET200 empty. Không simulated SUCCESS hoặc cấp quyền mới trong gate check. |

Không cộng UI/HTTP/DB/gate checks vào JUnit. **Không rerun1118full, unit/widget/analyze, model/accuracy/PAD/camera hoặc DB01upgrade**: merge tree/executable giống bản đã nghiệm thu. Builds mới chỉ phục vụ chạy smoke từ clean checkout.21native generated paths chỉ EOL, dependencies/source không đổi;10tracked UI screenshots của smoke clone thay đổi do chạy harness, không đưa chúng vào commit. Chỉ3ảnh mới đã review, tổng hợp, không password/OTP/token: [M04](pr8-postmerge/member-m04-real-activation.png), [Booking](pr8-postmerge/member-confirmed.png), [PT sau reload](pr8-postmerge/pt-reloaded-sessions.png).

JAR build từ main được kiểm lại: exact12SQL1–6,8–13/đúnghash, không V7/V14/callback legacy. Profile core-demo runtime xác nhận, Face check-in/test-adapter/enrollment/remote-service4gates=false. Simulator chỉ guarded dev/test/ADMIN ACTIVE; default an toàn, không service/Face/camera thật được khởi động. Mọi mail là loopback/example.invalid.

## Cleanup và giới hạn

Cleanup sealed UUID2lần đạt trên demo pair2DB/31PK; root registry verification2DB không thêm fixture, không cộng trùng.0failure; dừng đúng PID/start-time/command của process task và2containers mới, giữ volumes/schema/history. Không truncate/drop/reset/repair/out-of-order/reseed hoặc tác động workload khác. Credentials/authority/logs/build nằm private ngoài Git.

Không deploy hoặc nâng cấp DB cũ/chung. **targetUpgradeVerified=false**; production inventory/backup/provenance vẫn cần cho target cụ thể. Face chưa nghiệm thu người thật: dataset/calibration/evaluation hoãn, NOT_PERFORMED/admission off. Simulator không gateway/tiền thật/refund hoặc production rollout. Không có smoke failure cần bản sửa; main không reset/chỉnh dữ liệu để che lỗi. [Final review trước merge](PR8_FINAL_REVIEW.md) và counts trong đó là evidence lịch sử tương ứng, không biến thành lượt full mới.
