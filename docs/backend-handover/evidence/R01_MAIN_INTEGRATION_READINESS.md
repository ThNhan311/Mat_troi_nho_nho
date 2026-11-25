# R-01 — Khả năng tích hợp FitCenter vào main, 25/11/2026

**Chưa đề xuất merge để nghiệm thu Core.** Git có thể fast-forward ở snapshot hiện tại, nhưng chuỗi DB/reproducible setup và tài liệu còn blocker. Đây là khảo sát, không sửa executable source, không merge/cherry-pick/push, không chạy migration hoặc kết nối DB chung. [Inventory/lineage/checks máy đọc](R01_MAIN_INTEGRATION_RESULTS.json), [trạng thái tiếp tục](../../PROJECT_STATUS.md).

## 1. Git và source đồng đội

Worktree tích hợp: `Mat_troi_nho_nho-booking-integration`; branch `feature/face-camera-evaluation`, HEAD/remote branch `f45d55a77d7338cdfbe5ad9aeb4df2f18cea0c3d`. Main `5c8693bfaeb4c0e85f4c7bcb21c5fd487dad3516` là ancestor, **45 ahead / 0 behind**, không merge commit trong range. 24 mốc đóng task từ Task A đến F03B đều là ancestors; không có nhóm stable patch-id trùng trong45 commits. Các SHA/task đầy đủ trong JSON, không cần cherry-pick lại các task đã có trong nhánh cuối.

| Ref remote sau fetch/đối chiếu lại | SHA ngắn | So với nhánh cuối |
|---|---|---|
| main |5c8693b|Ancestor, chưa có commit main riêng cần hòa giải|
| backend |aee1b53|Ancestor, đã có trong lịch sử|
| frontend |0307242|2 commit riêng; đã import có chọn lọc3app, không merge cả nhánh|
| feature/database-schema |558fb03|2 commit riêng; canonical V1–V6 khớp6/6 Git blobs; nested V7 chưa import|
| feature/face-1n-identification |fcabeba|3 commit riêng; chỉ dependencies/algorithms đã chọn import, không đồng nghĩa toàn nhánh Face đã merge|

Provenance so với Frontend0307242: Member156files gốc không thiếu,14sửa+19mới; PT149files không thiếu,12sửa+13mới; Admin137files gốc,9sửa+19mới và1test `MyApp` cũ bỏ/thay bằng test chuyên biệt. Không mất màn hình gốc. Native/source ngoài luồng được giữ, không phải tất cả module gốc đã tích hợp. Thay đổi chưa push trên máy đồng đội không thể xác minh bằng refs remote.

Worktree gốc vẫn branch `feature/backend-service-eligibility`/089b5e2, không bị checkout hoặc ghi đè. 4research untracked22/11 giữ nguyên bytes;26Face untracked/cache/model gốc hash không đổi.

## 2. Blocker theo mức ưu tiên

| Ưu tiên | Phát hiện và nguồn | Điều kiện xử lý |
|---|---|---|
| **P0 — schema cho Core có thể sử dụng** | [POM](../../../backend/pom.xml) chỉ canonical V1–V6; V8–V13 ở location opt-in. V7 của Duy DROP `payment_transactions.period_start/end` trước backfill, trong khi M03/V11 vẫn dùng trực tiếp. Chưa có inventory DB chung. | Phải thống nhất đường upgrade bảo toàn dữ liệu/order/checksum trước khi bật Account/Membership write hoặc coi main release-ready. Không chép V7 vào canonical, không renumber/repair/out-of-order. Code-only merge với các tính năng đó off là phạm vi hẹp hơn, cần ghi rõ chưa nghiệm thu Core. |
| **P1 — runner/clean-machine** | Đã chạy read-only: [core inventory](../../../backend/scripts/core-migration-inventory.mjs), [renewal inventory](../../../backend/scripts/renewal-migration-inventory.mjs), [checkin inventory](../../../backend/scripts/checkin-migration-inventory.mjs) đều exit1 do candidate cũ không chứa migration task sau; [enrollment inventory](../../../backend/scripts/enrollment-migration-inventory.mjs) exit0. | Chuẩn bị một candidate/runner hiện hành, hoặc pin hướng dẫn cũ về đúng commit; không bỏ assertion/guard. Chạy lại documented setup trên checkout mới sau sửa. |
| **P1 — bootstrap resource** | [Account runner](../../../backend/scripts/account-integration-rehearsal.ps1) Provision dòng37 lấy image từ container `fitcenter-baseline-20261120-db` đã có; full suite dòng101 và [F02 runner](../../../backend/scripts/enrollment-integration-rehearsal.ps1) dòng113 hardcode baseline container ID của máy này. | Cho bootstrap image/digest, baseline/container identity/port có manifest riêng ở máy mới; không copy DPAPI/password/manifest của máy cũ hoặc nới guard. Hiện chưa có một đường Core setup end-to-end portable. |
| **P1 — entry docs và link** | [Backend README](../../../backend/README.md) vẫn hướng dẫn alignment và kết quả65tests cũ, trái [AGENTS](../../../AGENTS.md)/quickstarts hiện hành. Không có README ở root.10 links tracked trỏ tới4research chưa tracked, chỉ tồn tại trên máy này. | Trước merge cần entrypoint hiện hành, phân biệt historical/rehearsal/default và sửa/đưa đúng nguồn tài liệu đã review vào repository bằng task riêng. Không tự stage4file được yêu cầu bảo toàn. |
| **P1 — acceptance gate ứng viên cuối** | GitHub inventory hiện0workflow/run/deployment/webhook; chưa có lượt setup+regression/E2E cho nhánh tích hợp sau khi sửa blockers. | Dùng CI hoặc manual gate có evidence/source hashes cho ứng viên cuối. Không gọi absence of CI là pass, không rerun historical suites chỉ để bổ sung số ở R01. |
| P2 — phạm vi giao diện/native | Mock source cũ/dashboard còn trong repo nhưng không có route từ3main hiện hành; một số tính năng Chưa khả dụng. Pub get fresh clone làm21native generated paths hiện EOL-only status churn. | Giữ scope Web rõ; đừng stage noise hoặc quảng bá native/Workout/full Admin đã xong. EOL policy housekeeping không phải bug dữ liệu hoặc Web functional failure. |

R-01 không tự sửa các blocker này. P0 là blocker bật/nghiệm thu Core với schema mới, **không phải Git conflict**. Có thể giữ Face, simulator và rehearsal gates off trong main nếu scope merge ghi rõ; không được lấy việc code hiện diện làm bằng chứng tính năng đã phát hành.

## 3. Migration V7–V13 và dữ liệu

[Inventory đầy đủ SHA256/Flyway checksums](R01_MAIN_INTEGRATION_RESULTS.json); [candidate hiện hành](../../../database/enrollment-integration-candidate.json), [I01 quyết định/history](../decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md).

| Version/location | Thực tế và phụ thuộc | Trạng thái tích hợp |
|---|---|---|
| [V1–V6 canonical](../../../database/migrations/) | Users, Member/PT, Membership/payment có period columns, Face/Attendance, Booking/policy, Workout/notification, audit. | Đóng gói default, khớp ref Database. |
| [V7 tại ref558fb03](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/558fb03fd5927ca9e04d17b54fd46e429fe62bb5/database/database/migrations/V7__membership_periods.sql) | DROP ck_payment_period +2period columns; thêm uq payment id/plan, `membership_periods`, exclusion/unique/FK/checks, app_today, validation function/trigger và overview view. **Không backfill trước DROP**; model ACTIVATION không tx khác M03 ghi payment quầy. | Quarantine, chưa áp bởi task này; không biết đã áp ở DB đồng đội hay chưa. Không merge nguyên nested tree. |
| [V8 activation](../../../database/activation-rehearsal/V8__pt_account_activation.sql) | PT challenge/grant/counter state, User/PT/audit provenance. | Rehearsal riêng/default-off. |
| [V9 initial membership](../../../database/membership-rehearsal/V9__membership_initial_activation.sql) | Composite identity FKs, receipt/idempotency/audit/price-duration-response snapshots; phụ thuộc V2/V6. | Rehearsal; không đổi tên/version đã công bố. |
| [V10 MEMBER activation](../../../database/member-activation-rehearsal/V10__member_account_activation.sql) | Bảng role MEMBER riêng, không cho chéo PT grant/challenge; state/account provenance. | Rehearsal tích hợp. |
| [V11 paid periods/renewal](../../../database/renewal-rehearsal/V11__membership_renewal_simulator.sql) | `membership_paid_periods`, quotes/result keys/events; dùng V9 và **payment period columns V2**. Backfill M03 INITIAL_COUNTER và LEGACY_AGGREGATE minh bạch, không bịa giá/lịch sử chi tiết. | Không thể ghép nguyên sau V7 DROP hiện tại. |
| [V12 check-in](../../../database/checkin-rehearsal/V12__checkin_request_ledger.sql) | Idempotency ledger/dedupe/identity proof với V3/audit. | Test identity, default-off. |
| [V13 enrollment](../../../database/enrollment-rehearsal/V13__face_enrollment_lifecycle.sql) | Profile generation/mapping, operations/revocations/cleanup, consent/actor, journal compensation; mode hiện SIMULATED_TEST. | Không phải schema mở admission Face thật. |

Candidate test có history1–6,8–13, **không phải canonical release**. Applied history trong evidence là DB private lịch sử, không phải inventory DB chung vừa kiểm. V7 đưa vào sau8+ sẽ bị validate/order conflict; giữ `out-of-order=false`. Nếu V7 chưa áp nơi đích: cần SQL/version/order được phối hợp và backfill/verify trước drop. Nếu đã áp: phải giữ migration/checksum đó, inventory/backup/restore hoặc append corrective migration có kiểm chứng; dữ liệu bị drop không thể tái tạo từ giá plan hiện tại. Không sửa history hoặc reseed để giả bảo toàn. R01 không thiết kế/áp DDL thay thế.

## 4. Checklist yêu cầu và evidence

**Đạt** bên dưới là phạm vi task đã có code + evidence lịch sử, không phải kiểm thử mới ở R01. **Có điều kiện** nghĩa là phải dùng guarded rehearsal/location tương ứng. UI thật/API thật tách khỏi unit/widget và simulated identity.

| Yêu cầu | Backend / Frontend / evidence | Đánh giá và phần thiếu |
|---|---|---|
| Login/refresh/ACTIVE/RBAC/ownership, session memory/epoch | [SecurityConfig](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/SecurityConfig.java), [original UI evidence](ORIGINAL_UI_INTEGRATION.md) | Đạt phạm vi Web đã test;3app main dùng Login/Home/navigation gốc. |
| Admin tạo Member/PT nguyên tử, chưa ACTIVE | [AdminAccountService](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/AdminAccountService.java), [account evidence](ACCOUNT_PT_ACTIVATION.md) | Đạt tạo/list; account status edit/delete chưa triển khai. Tạo User không cấp Membership. |
| PT/MEMBER email→OTP→password→ACTIVE | [PT DB evidence](PT_ACTIVATION_POSTGRES.md), [MEMBER evidence](MEMBER_ACCOUNT_ACTIVATION.md) | Có điều kiện;5phút/attempt/resend/one-use/concurrency và UI+mail sink đã test. Default-off, mail chỉ loopback/example.invalid; production mail/schema rollout chưa có. |
| M01 plan ACTIVE create/list/detail | [M01 evidence](M01_PLAN_CREATE.md) | Đạt; price0, int32/decimal, duplicate names đúng contract. Không full CRUD/INACTIVE management. |
| M03 quầy/initial activation/idempotency | [M03 evidence](M03_INITIAL_MEMBERSHIP.md) | Có điều kiệnV9; snapshot/receipt/transaction/rollback và UI/DB đã test. Không kích hoạt tài khoản hoặc gateway. |
| M04 Member xem own Membership | [M04 evidence](M04_MEMBER_MEMBERSHIP.md) | Đạt read-only+UI; không chọn array[0] làm current. Period read sau renewal tùy V11 gate. |
| M05/M06 gia hạn và simulator | [Renewal evidence](M05_M06_RENEWAL_SIMULATOR.md) | Có điều kiệnV11; pending/snapshot/paid coverage/concurrency/replay/reconciliation và UI HTTP DB đã test. Simulator test-only/ADMIN, không gateway/refund. |
| PT availability create/PATCH/DELETE;90phút/replacement UUID | [R02](R02_PT_AVAILABILITY_WRITE.md), [Web lifecycle](BOOKING_WEB_LIFECYCLE.md) | Đạt API/HTTP/PG +UI; DELETE DISABLED, FK history và locks giữ nguyên. |
| Member Booking CONFIRMED, lịch/cancel/rebook; PT cancel/complete | [R03](R03_BOOKING_CREATE.md), [R04](R04_BOOKING_LIFECYCLE.md), [Web original UI](ORIGINAL_UI_INTEGRATION.md) | Đạt phạm vi đã chốt; locks/time/VN/409/ownership/replay checks. Không PT approval hoặc PENDING booking. |
| Admin GET/PUT policy ngay hiệu lực | [Policy write](BOOKING_POLICY_WRITE.md), [Admin UI](ADMIN_BOOKING_POLICY.md) | Đạt; không default fallback, không scheduling/versioning đầy đủ theo D05. |
| D01 snapshot service eligibility | [D01 evidence](SERVICE_ELIGIBILITY.md), [Web lifecycle](BOOKING_WEB_LIFECYCLE.md) | Đạt API/snapshot/UI; không start marker/IN_PROGRESS, complete giữ R04. Không tuyên bố chặn vật lý end-to-end. |
| F01 Core attendance/dedupe/own history | [F01 evidence](F01_CHECKIN_CORE.md) | Có điều kiện; simulated trusted identity tests/API/DB, không Face ID thật. |
| F02 enrollment lifecycle và mapping | [F02 evidence](F02_FACE_ENROLLMENT.md) | Có điều kiện; simulated adapter/UI, compensation/revoke, không enrollment người thật. |
| F03A service/model và F03B tools | [F03A](F03A_FACE_SERVICE.md), [F03B](F03B_CAMERA_EVALUATION.md) | Tooling ready; protocol tests và generated-input model smoke có evidence.25/11 operator báo preview camera ổn; **dataset/calibration/evaluation người thật chưa chạy**, accuracy=null. |
| Workout/notifications/profile editing/native/mobile/full Admin reporting/gateway/refund | [Roadmap](../08_DEVELOPMENT_ROADMAP.md), [Home Member](../../../frontend/fitcenter_member/lib/screens/home_page.dart), [Home PT](../../../frontend/fitcenter_pt/lib/screens/home_page.dart), [Home Admin](../../../frontend/fitcenter_ad/lib/screens/home_page.dart) | Ngoài các task Core/Web đã nghiệm thu; nhiều phần mới schema hoặc nguồn mock cũ, không coi là toàn bộ FitCenter hoàn thành. |

## 5. Default-off, mock reachable và tài liệu/secret

- Ba entry [Member](../../../frontend/fitcenter_member/lib/main.dart), [PT](../../../frontend/fitcenter_pt/lib/main.dart), [Admin](../../../frontend/fitcenter_ad/lib/main.dart) dùng auth thật và Navigator theo session; dashboard replacement không reachable từ entry. Không tìm thấy route public quay về demo login không xác thực.
- Admin Home tổng quan dùng `—`/Chưa khả dụng, không số hội viên/doanh thu giả. Workout/history hệ thống/profile edit và các module chưa có contract bị Chưa khả dụng. Legacy mock pages còn là source, không đồng nghĩa runtime fallback. Đây là static route review, không UI traversal mới ở R01.
- Admin menu Face/simulator **vẫn reachable**; simulator ghi rõ Dev/test/không tiền thật. Backend off phải trả lỗi/không ghi state; không coi menu visible là service enabled. Face thật/PAD/threshold/admission giữ off, chưa nghiệm thu. Default config chỉ V1–V6; Account/M03/Renewal cũng chưa được bật như release.
- Scan latest tracked text không thấy private-key/GitHub-token/JWT/literal-env-secret theo patterns; không thấy tracked target/build/.dart_tool/venv/model/cache/private credential artifacts. Không phải forensic scan toàn Git history/OCR mọi ảnh; review ảnh trước đây là evidence lịch sử, R01 không tạo ảnh mới. Private runtime/authority/log/consent/dataset không đưa vào báo cáo.
- Working tree hiện resolve được links, nhưng clean clone thiếu **10links→4file research untracked**; danh sách đủ trong JSON. Trước merge sửa link sang nguồn tracked phù hợp hoặc review riêng4file để đưa vào repo, không tự gộp. Các quickstarts14–25 là task lịch sử/guarded environments; cần một START_HERE hiện hành thay chỉ dẫn alignment cũ. Comment “proposed currency” trong V9 đã áp là chú thích lịch sử; quyết định đã chốt ở [M03](../decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md), không sửa SQL đã áp để chỉnh lời văn.

## 6. Kiểm tra setup thực chạy ở R01

Clone mới từ GitHub vào Temp riêng, detached đúngf45d55a, source tracked ban đầu sạch. Không copy untracked/credential/build từ worktree đang làm.

| Kiểm tra mới | Kết quả | Giới hạn |
|---|---|---|
| 24task ancestors / stable patch comparison / main ancestry |24/24 có;0patch duplicate;45/0main|Snapshot remote hiện tại, không biết work chưa push|
| Read-only candidate inventory |1đạt(F02),3fail(I01/Renewal/F01)|Không thực thi SQL; failure là blocker setup thật|
| JDK21 + Maven offline process-resources |exit0,12SQL resource hashes khớp source;default6/rehearsal6|Không compile/package/test hoặc khởi động Spring/Flyway|
| Flutter3.50.1/Dart3.14, pub get offline/enforce-lockfile |3/3app exit0,lock không đổi|21native generated paths hiện EOL-only status; normalized content khớp HEAD|
| Docs/secret/artifact/latest hashes |11F03Bhashes khớp;Backend/database không đổi từF03A;0patternsecret;10untrackedlinks|Dùng cache SDK/Maven/Pub hiện có, chưa là cold machine bootstrap|
| CI/CD GitHub |0workflow/run/deployment/webhook|Không phải CI pass|

**Không chạy unit/full regression, HTTP/DB/UI/E2E mới**. Backend1106/F03A và Python101+47/1skip F03B là lịch sử tại source tương ứng, không cộng vào checks R01. Không tạo dataset, ảnh, embedding hoặc accuracy; không đổi threshold/liveness/admission. Operator đã báo camera preview ổn, không có process/cửa sổ preview còn chạy lúc rà soát; không mở lại camera. Không start DB/backend/service, volumes không đổi. Giữ clone/logs thử riêng ngoài Git, không copy generated changes về worktree.

## 7. Nhánh tích hợp và test gate đề xuất

Chưa tạo/merge nhánh tích hợp trong R01. Sau khi thống nhất scope main, đề xuất **`integration/core-main-readiness` từf45d55a**; fetch lại main/database/frontend/Face, kiểm SHA và ancestry. Vì main đang ancestor, không cần cherry-pick24task hoặc merge toàn frontend/database/Face; nếu main tiến thêm, review diff mới trước khi chọn merge và chạy lại affected checks. Tách các commit sửa migration-release plan, portable bootstrap, docs/link/gates; giữ SQL đã công bố nguyên byte và không enable Face mặc định.

Trình tự gate trước merge/nghiệm thu:

1. Chốt inventory/checksum/order từng DB đích với nhóm Database; rehearsal chain đã thống nhất trên DB trống + DB lịch sử synthetic, so rows/periods/receipt/snapshots/account state trước/sau và rollback. Không DB chung/repair/clean/out-of-order; nếu thiếu inventory thì chỉ nghiệm thu guarded test candidate, không release-ready.
2. Fresh clone/máy hoặc container công cụ mới: bootstrap JDK21/Docker17/Flutter/Dart/Node/Python locks, full verified image/container/volume/ports mới, resource manifests mới, credentials local mới, mail sink loopback; chứng minh không phụ thuộc ID/DPAPI/cache máy cũ. Xác minh12resources/defaultoff/V7 quarantine trước Flyway.
3. Sau thay đổi executable setup/schema: focused cho phần sửa rồi **một selected full Backend** theo scopes rõ (baseline Booking + integrated account/M03/renewal/F01/F02/F03A nếu đi cùng), fresh reports/source hashes, không cộng focused. Chọn riêng legacy standalone profiles cần bổ sung; không gọi selector loại3lớp cũ là mọi profile đã chạy.
4. Analyze/test/build3Flutterapps và client/session/epoch/timeout/409 mapping; phân biệt unit/widget với HTTP/DB/UI. Python F03A/F03B/pinned regression nếu modules được giữ hoặc bị ảnh hưởng; manual camera/PAD/accuracy vẫn chưa nghiệm thu, không ép thu người thật.
5. Một guarded environment/mail sink: Admin tạo plan/MEMBER/PT→M03→OTP hai role→M04→PT slot→Member booking/cancel/rebook→hai lịch cùng UUID→reload/login; thêm renewal pending→Admin simulated result→period read-back/replay/rollback/ownership. Seed chỉ Admin+minimum không có write API. Ghi rõ simulated payment/Face, không admission thật; cleanup exact UUID/process, giữ volume.
6. Gate final: docs links từ clean clone, secret/artifact scan, diff review với đồng đội, Face/simulator/test-only/default gates, remote SHAs, evidence gắn candidate commit. CI hoặc manual sign-off rõ; chỉ sau đó mới đề xuất PR/merge, R01 chưa thực hiện.
