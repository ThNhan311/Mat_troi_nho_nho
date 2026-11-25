# PR #8 — final review fresh Web Core demo, 25/11/2026

**Kết luận: có thể merge trong phạm vi fresh Web Core demo; không có finding mở cần chặn merge.** [PR #8](https://github.com/ThNhan311/Mat_troi_nho_nho/pull/8) đã được chuyển Ready for review (draft=false), merged=false. Lượt này **không merge/deploy hoặc thay DB chung**. Production/legacy-target rollout và Face thật không thuộc kết luận này.

Reviewed input HEAD **d7a39cf2b723b9b87550d38004e6140fe206621a**, base main **5c8693bfaeb4c0e85f4c7bcb21c5fd487dad3516**, nhánh release/core-main-candidate. Fetch/PR metadata/local/upstream đều khớp; main ancestor,56ahead0behind ở input; không có incoming remote changes. Commit review tiếp theo chỉ tài liệu/trạng thái, Git/PR là HEAD xuất bản thực tế.

## Source và evidence

Đối chiếu **390/390 Git blob SHA256** trong [evidence ứng viên](CORE_MAIN_CANDIDATE_RESULTS.json) với input HEAD: khớp toàn bộ executable/test/helper đã kiểm thử tại27e8beaf0ac835b2032ab71de3e9cc399fd49fad. Khác biệt sau source đó chỉ docs/evidence/env sample; không source Java/Dart/Face/migration mới.14SQL hashes (12published +2DB01) giữ nguyên. Không sử dụng raw Windows checkout EOL để kết luận sai thay đổi executable.

Tái sử dụng [manual evidence](CORE_MAIN_CANDIDATE.md): selected Backend1118passed0failed/errors/skipped,44XML suites; Flutter Member80/PT55/Admin133/analyze/build; combined49UI/39HTTP/18DB cùng Backend/DB/mail; private DB01 matrix196checks/13scenario. Đây là **kết quả lượt ứng viên trước**, không phải tests vừa chạy trong final review. Ba standalone historical profiles, native, accuracy/PAD/camera người thật vẫn chưa được chọn/kiểm chứng trong phạm vi này. Không cộng focused/checks vào full.

Lượt review mới chỉ đọc Git/source/package/cấu hình, manifest/hashes, links/secret/artifact và GitHub state. **0functional suites/build/compile mới;0DB connections;0migration executions.** Không phát hiện thay đổi/rủi ro cụ thể cần rerun chức năng. Workflow runs/statuses GitHub cho input HEAD đều0: **manual evidence không phải CI pass**.

## Trọng tâm đã review

| Khu vực | Kết luận |
|---|---|
| Fresh migrations/runner | [Core runner](../../../backend/scripts/core-readiness.ps1), [demo helper](../../../backend/scripts/CoreIntegrationDemo.java), [manifest](../../../database/core-demo-candidate.json), [POM](../../../backend/pom.xml) dùng exact1–6,8–13; không V7/V14/callback legacy. Kiểm trực tiếp JAR đã test: đúng12SQL/đúng hashes, không legacy callback. Default chỉ V1–V6, không sửa published SQL/history. |
| Guards/Face/simulator | [core-demo](../../../backend/src/main/resources/application-core-demo.properties), [pre-Flyway guard](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/activation/AccountIntegrationRehearsalConfiguration.java), [renewal guard](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/renewal/RenewalSchemaGuard.java): profile riêng/loopback/role/location guard; Face check-in/test adapter/enrollment/remote service đều false; simulator chỉ guarded dev/test và ADMIN ACTIVE. Default gates không bật các luồng này. |
| Auth/OTP/RBAC | ACTIVE check ở JWT filter/auth, Admin-created marker và role-specific activation stores, OTP/grant one-use/Clock sau khóa/expiry-attempt-resend; không JWT trước ACTIVE, account activation không tạo Membership/payment. Không public client tự khai identity để vào gym. |
| Membership/payment | M03 transaction Member-first, snapshot/receipt/idempotency nguyên tử; renewal quote snapshot, independent SUCCESS tuần tự, duplicate/reordered/reconciliation và ownership có kiểm soát. Current/next/history dùng paid periods; M04 planId/name cùng plan, null lịch sử không bị dựng thành snapshot. |
| Booking | Auto-confirm90phút, coverage ngày VN/UTC, effective policy/no fallback, Member→membership→PT→slot và lifecycle Member lock tương thích. Recheck sau chờ, rollback atomic; cancel cũ không tác động rebook. |
| UI/session/write errors |3entry Login/Home/navigation gốc; API_BASE_URL dart-define/token memory/session epoch; không write replay khi timeout/401, 204 không decode,409reload/replacement UUID và snapshot eligibility đúng contract. Không mock fallback/fake success trong luồng chính; module ngoài scope Chưa khả dụng. |
| Docs/setup/upgrade | [README](../../../README.md), [setup](../../INTEGRATION_SETUP.md), [upgrade](../../DB01_UPGRADE.md) phân biệt fresh/private và DB cũ; credentials/manifest mới, image pin/guards/cleanup giữ volume. targetUpgradeVerified=false rõ ràng; không coi DB cũ/production đã nâng cấp. |

Scan tracked text theo patterns không phát hiện private key/GitHub token/JWT; không tracked SDK/cache/build/dataset/model/embedding/private authority/raw logs. Không phải forensic toàn Git history/OCR mọi ảnh lịch sử.7ảnh evidence ứng viên đã được review ở lượt trước, synthetic, source không đổi.1006local links tại input HEAD resolve; bổ sung báo cáo này được kiểm links trước push.4research untracked/26Face/model/cache giữ nguyên hashes, không stage. Không khởi động camera/process/DB nào.

## Finding và giới hạn còn lại

**Finding mở trong fresh demo scope:0. Không sửa executable hoặc thêm test để tạo evidence lặp.** PR Ready, chưa merge; quyền merge vẫn cần lượt người dùng giao riêng.

Các giới hạn production giữ nguyên, không đổi thành blocker fresh demo: targetUpgradeVerified=false/chưa có real old target inventory+backup; thiếu provenance/refund/conflict cần reconcile trước upgrade. Simulator không tiền thật/gateway/refund. Face tooling ready; thu dataset/calibration/evaluation người thật đang hoãn, accuracy chưa có, liveness NOT_PERFORMED/admission thật tắt. Native/mobile/production mail và toàn bộ FitCenter ngoài Core không được quảng bá hoàn thành.
