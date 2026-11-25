# FitCenter — trạng thái tiếp tục

Cập nhật25/11/2026. Worktree `Mat_troi_nho_nho-booking-integration`; branch **feature/face-camera-evaluation**, HEAD/remote **f45d55a77d7338cdfbe5ad9aeb4df2f18cea0c3d**. Task hiện tại **R-01 khảo sát khả năng tích hợp main**, chỉ docs/report, chưa commit/push/merge. Git là thực tế.

## F03B tạm hoãn thu mẫu theo yêu cầu người dùng

**Tooling ready; dataset/calibration/evaluation người thật chưa chạy**, accuracy=null.25/11 operator xác nhận preview camera ổn; không còn process/cửa sổ preview lúc rà soát, không mở lại camera. Chưa tạo study/consent/ảnh/embedding người thật. Không đổi threshold, `liveness=NOT_PERFORMED`, admission=false; không nghiệm thu Face ID/PAD/production threshold. [Operator quickstart](backend-handover/25_FACE_CAMERA_EVALUATION_QUICKSTART.md), [evidence F03B lịch sử](backend-handover/evidence/F03B_CAMERA_EVALUATION.md). Python101repo +47pinned/1manualskip là lịch sử tạif45d55a, không vừa chạy ở R01.

## R-01 — Git tích hợp được, Core chưa release-ready

Fetch+đối chiếu remote: main5c8693b ancestor, **45ahead/0behind**;24mốc task đều có,0stablepatchduplicate. Không cần cherry-pick lại hoặc merge toàn nhánh Frontend/Database/Face. V1–V6 khớp Database558fb03; V7 vẫn destructive/quarantine, shared applied history chưa biết. Code-only merge/default-off khác với nghiệm thu Core đầy đủ. [Báo cáo/checklist/blockers/test plan](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md), [Git/migration/checks JSON](backend-handover/evidence/R01_MAIN_INTEGRATION_RESULTS.json).

Blocker theo ưu tiên:

- **P0 Core schema rollout:** V7 DROP period columns chưa backfill, xung đột M03/V11; V8–V13 chỉ location rehearsal/gap7, không canonical release. Chưa inventory DB chung. Không rewrite/renumber/out-of-order/history edits/clean/repair.
- **P1 setup:** read-only inventories I01/Renewal/F01 fail vì migrations task sau; chỉ F02 candidate hiện hành đạt. Runner Provision/full còn phụ thuộc baseline container/image/ID máy cũ.
- **P1 docs/gate:** Backend README vẫn alignment/cũ;10links trỏ4researchuntracked, thiếu trên clean clone; chưa có acceptance gate cho candidate tích hợp sau sửa. GitHub0workflow/run/deployment/webhook, không CI pass.
- Face thật/PAD/accuracy, gateway/refund, native/mobile/Workout/full Admin nằm ngoài nghiệm thu này; Face giữ default-off. Mock legacy không reachable từ3entry hiện hành; Admin simulator/Face menu vẫn reachable nhưng Backend gate và nhãn test phải giữ.

## Checks mới và phạm vi chưa commit

Fresh clone f45d55a riêng: JDK21/Maven offline `process-resources` exit0,12SQLresources hash đúng/default6+rehearsal6;3Flutterpubget offline/enforce-lockfile đạt,lock không đổi.21nativegenerated paths hiện EOL-only status trong clone thử, normalized content khớp; không copy về worktree. Dùng SDK/Maven/Pub cache hiện có, chưa chứng minh cold máy mới. **Không rerun unit/full/HTTP/DB/UI/E2E** hoặc áp migration.11F03Bsourcehashes còn khớp; Backend/database không đổi từ F03A1106 lịch sử.

Uncommitted của R01: status này, ghi chú tạm hoãn trong DECISIONS và2report R01.4research22/11 ngoài task giữ nguyên;26Face untracked/cache/model gốc hash không đổi. Không secret/private manifest/log/SDK/cache/build hoặc dữ liệu biometric trong scope docs. Không source executable, DB/volume/process chung bị đổi, không start tài nguyên demo.

Bước tiếp: xử lý blocker trên nhánh đề xuất **integration/core-main-readiness từf45d55a** (chưa tạo), phối hợp inventory/release plan DB, portable runner và current entry docs, rồi chạy selected regression/E2E gate trên ứng viên cuối. R01 chỉ khảo sát, không tự triển khai fixes hoặc merge. [AGENTS](../AGENTS.md), [quyết định](DECISIONS.md).
