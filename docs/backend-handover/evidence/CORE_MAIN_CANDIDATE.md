# Core main candidate — 25/11/2026

**Fresh Web Core demo đạt; ứng viên để review, chưa merge/deploy/DB chung.** Branch release/core-main-candidate, executable source **27e8beaf0ac835b2032ab71de3e9cc399fd49fad**; M04 fix4e0c243, base DB01 8d3aa979. Commit đóng tiếp theo chỉ docs/evidence/env sample. [Kết quả/suites/390 raw và Git blob hashes](CORE_MAIN_CANDIDATE_RESULTS.json), [setup](../../INTEGRATION_SETUP.md), [upgrade](../../DB01_UPGRADE.md), [quyết định](../../DECISIONS.md).

## Phạm vi và thay đổi cuối

Fullest branch đã chứa24task anchors A→F03B, R02 và DB01. Main5c8693b là ancestor; source candidate54ahead/0behind, không stable patch-id duplicate. Database558fb03/Frontend0307242/Facefcabeba không đổi qua fetch. Không merge/cherry-pick lại nguồn đồng đội. Diff main tại executable source1089files là toàn bộ Core/Web và tài liệu tích lũy; review task cuối sửa M04, isolated Core profile/runner/combined harness, setup/upgrade decisions. Provenance gốc ở [R01](R01_MAIN_INTEGRATION_READINESS.md), [R02](R02_PORTABLE_SETUP.md), [DB01](DB01_MIGRATION_COMPATIBILITY.md).

- M04 planId/name cùng paid-period plan: giữ name snapshot có nguồn; legacy thiếu snapshot tra live catalog đúng UUID. Period/history thiếu name/price/duration/currency vẫn null. Tests PostgreSQL kiểm CURRENT/HISTORY với aggregate plan khác, legacy null và owner isolation; NEXT đã có regression.
- Fresh private demo pin12SQL **V1–V6,V8–V13**, [manifest](../../../database/core-demo-candidate.json), không V7/V14/callback legacy. V14 upgrade-only vì fresh đã có canonical paid periods. Giữ nguyên14SQL được công bố (12migrations +2DB01SQL), V7 nguyên pin/ref/checksum; không renumber/history/repair/clean/out-of-order. Version gap hợp lệ theo quyết định mới.
- Profile core-demo giữ resource/datasource/location/role guards, bật OTP/mail sink/M03/renewal/Admin simulator rõ ràng. Check-in/test adapter/enrollment/remote Face service đều false; không tạo kiosk/journal giả để khởi động Core. Default gates giữ an toàn.
- README/setup/env/upgrade phân biệt fresh demo và DB cũ. Không cần ID/credential/DPAPI/manifest/build từ máy trước; private scope và secrets mới trên máy đích. Historical reports giữ nguyên kết quả/giới hạn tại thời điểm đó.

## Kiểm thử mới thực chạy

| Scope | Kết quả | Nguồn/giới hạn |
|---|---|---|
| Backend selected full | **1118passed,0failed/errors/skipped;44XML suites** | JDK21, PostgreSQL17.12 riêng; Booking/default, integrated Account/M03/renewal/F01/F02/F03A. |
| Focused Java |47passed,0failed/errors/skipped|Subset của full, không cộng. Mock setup/compile typo trong quá trình sửa đã được sửa trước lượt cuối. |
| Flutter Member |80passed,0failed/skipped|Analyze --no-fatal-infos exit0; Web build exit0. |
| Flutter PT |55passed,0failed/skipped|Như trên. |
| Flutter Admin |133passed,0failed/skipped|Như trên. |
| Combined UI / HTTP / PostgreSQL |**49 /39 /18**,0failed/skipped|Chrome headless thật1024×768; browser America/Los_Angeles; cùng backend/DB/mail, Clock thật. |
| Upgrade compatibility |**196checks/13scenarios**,0failed/skipped|Real PostgreSQL + JDBC services, không UI/E2E. |
| Node units / PowerShell guards |21tests /21checks,0failed/skipped|Resource identity và Web assets/preflight/parser guards. |

Full selector: `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`. Ba standalone location/profile suites lịch sử **không được chọn**, integrated replacements đã chạy. Không cộng focused, HTTP/DB/UI hoặc migration checks vào1118. Python accuracy/PAD/camera/F03B evaluation suites không chọn; Face protocol PostgreSQL/service tests nằm trong selected full. Không rerun model inference/accuracy vì không sửa model. Không dùng668/1106 hoặc196cũ làm lượt mới.

## Checkout sạch và E2E cùng scope

Clone mới từ remote, fetch đúng local candidate27e8bea, detached source clean ban đầu; không copy build/credentials/authority. Provision tạo mới2container/volumes/role/crypto credentials/manifest, image17.12 ghim digest; Build kiểm exact packaged12SQL trước Flyway, Verify đạt. Dùng cache Maven/Pub/FlutterSDK/Python/image có sẵn, **không cold install**. SDK/deps/weights không đổi.21native generated paths chỉ đổi EOL sau pub get, normalized content khớp HEAD; không copy về commit.390Git blob hashes source cuối khớp đúng checkout test.

Commands theo [setup](../../INTEGRATION_SETUP.md): Provision→Build→Verify→Test FullSuite; ba Flutter pub get --offline --enforce-lockfile/analyze/test/build với same API_BASE_URL; PrepareDemo Core→ServeBackend core-demo/mail sink/3Webservers→`verify-core-integration.mjs ... --combined`; cleanup2lần và Stop. Raw logs private; không copy XML system properties, authority hoặc OTP.

Chỉ seed synthetic Admin. Plan tạo qua Admin UI; Admin tạo Member/PT DISABLED, policy và M03 COUNTER/receipt qua API thật. Member/PT email→SMTP sink→OTP→password→ACTIVE qua UI gốc; không seed ACTIVE. M04 đọc đúng Membership UUID/ngày; PT tạo90phút slot qua UI; Member book CONFIRMED, hai bên đọc cùng UUID/time. Member cancel mở slot rồi thao tác mới rebook UUID mới; request cancel cũ409 không tác động booking mới. Reload/login Member/PT đọc đúng server.

Tiếp tục **chính Member/Membership/backend/DB/mail trên**: tạo plan renewal giá0 qua API, Member UI tạo PENDING, Admin UI mô phỏng SUCCESS; DB có đúng2paid periods, aggregate original plan FK giữ nguyên. Member reload/login đọc CURRENT/NEXT. FAILED/CANCELLED không đổi hạn, exact replay không thêm period/audit, late failure409 không downgrade SUCCESS; owner khác404/Member simulator403. M03 payment/receipt và Booking hiện có giữ nguyên. Face GET503 ERR_FACE_ENROLLMENT_UNAVAILABLE,0enrollment, không Face service/process chạy.

Readback synthetic: Membership37a01968-a4e1-4940-bfb8-d6e8f0b7a811; booking gốcd0c26f91-c1be-473b-9dfc-52df0431b8a3; rebook35745dd3-a8b4-444d-9ac6-0638413b80ac; SUCCESSebe368e1-c2e1-46d7-9129-4e1a145dc2dc. DTO/time/plan/period UUID đầy đủ trong JSON, không credential.

Ảnh mới đã review cùng viewport, chỉ dữ liệu tổng hợp: [Admin plan](core-main-candidate/admin-created-plan.png), [M04](core-main-candidate/member-m04-real-activation.png), [Booking](core-main-candidate/member-confirmed.png), [cancel](core-main-candidate/member-cancelled-slot-reopened.png), [PT lịch sau reload](core-main-candidate/pt-reloaded-sessions.png), [Admin simulator](core-main-candidate/admin-success.png), [Member CURRENT/NEXT](core-main-candidate/member-current-next.png). Giữ UI/theme/navigation gốc, không dashboard thay thế.

## Upgrade, cleanup và giới hạn phát hành

Ma trận private mới13scenario: protected-original-V7 compatibility simulation, V6history, V7history, existingCore, existingLegacyCore, conflictingEvidence, M03beforeV11, duplicateReceipt, missingCoverage, missingPaymentProvenance, REFUNDED, wrongBinding, overlapRollback. Kiểm bảo toàn source rows/period dates/receipts/snapshots/activation, Member-first concurrency/rollback và paid coverage Booking/D01. Scenario protectedV7 sao lưu nguồn trước DROP; **không** là fresh path được chọn. Không dựng quote/COUNTER/receipt từ giá plan hôm nay.

Inventory metadata read-only đúng5resources có authority của R02/DB01 trước, tất cả stopped, không kết nối dữ liệu DB cũ/DB chung. Đây là tài nguyên test lịch sử, không tự nhận là target production cần nâng cấp. **targetUpgradeVerified=false**; thiếu real target/inventory/backup/provenance là giới hạn rollout đích đó, không chặn fresh demo hoặc PR review. DB đã V7 cần compatibility trước V9/V11 rồi V14, archive/read-only view, canonical paid periods duy nhất. Refund/provenance/conflict cần reconcile, không cấp quyền âm thầm.

Cleanup sealed UUID **hai lần**: root12DB/1458PK, combined2DB/50PK (scope riêng, không cộng trùng), upgrade13DB/277PK;0failure,3outside rows giữ nguyên fingerprints. Không truncate/drop/reset/reseed/history edits. Dừng đúng task PID/start-time/command và2containers mới, giữ volumes/schema/history; app/mail/Web/DB task ports giải phóng. Không đổi workload khác.4research untracked/26Face/model/cache giữ nguyên hashes.

Secret/artifact/latest links/default gates/published SQL/source hashes đã review. GitHub main0workflow runs/0statuses, **không CI pass**. PR là draft; không còn blocker kỹ thuật được biết cho **fresh Web Core demo scope** sau các gate trên. Vẫn cần reviewer review/cho phép merge. Production rollout DB cụ thể, production mail/gateway/refund/native/mobile và Face accuracy/PAD/camera-to-admission chưa được chứng minh; Face tooling ready, dataset/calibration/evaluation người thật hoãn, NOT_PERFORMED/admission thật off. Không có quyết định nghiệp vụ mới cần người dùng trả lời trong task này.
