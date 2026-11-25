# DB-01 — V7 / Backend Membership compatibility rehearsal

**Đã chuẩn bị và kiểm thử hai đường chuyển đổi trên DB riêng; chưa release-ready.** [Thiết kế/contract/chạy lại/inventory owner](../../DB01_UPGRADE.md), [kết quả + source hashes + migration matrix](DB01_RESULTS.json), [manifest candidate](../proposals/db01/candidate-manifest.json).

Branch `feature/db01-migration-compatibility`, base R02 `ee95e0ccb57475d2b41bb766af11523d2e9b6c66`, source commit **fd603d7ad1939caf868f663c7e560bc63767bfcf**. Commit đóng sau đó chỉ docs/evidence. Fetch mới nhất: main5c8693b, Database558fb03, frontend0307242 không đổi. Không merge, không kết nối/apply DB chung hoặc production; không chạm4research untracked và26Face/model/cache đã đối chiếu hashes.

## Phương án đã thử

`membership_paid_periods` là nguồn kỳ cấp quyền duy nhất. V14 candidate giữ toàn bộ rows V7 trong archive chặn DML, đổi tên legacy thành read-only view trên canonical, overview cũng đọc canonical. Không có hai bảng period cùng nhận write độc lập. M03/Renewal giữ writer, transaction và khóa Member-first hiện có. Payment dates giữ vì code vẫn dùng, không được dùng làm nguồn coverage thứ hai.

Compatibility callback có SQL riêng và Java receipt normalizer: backup/backfill source dates trước original V7 DROP, restore sauV7 **trước V8/V9/V11**; DB đã ápV7 thì restore từ exact V7 binding/backup/evidence/M03 snapshot trước pending migrations. Không đoán từ plan giá/ngày hiện tại. ACTIVATION V7 không payment được giữ nguyên provenance/receipt, không tạo COUNTER payment giả; M03 COUNTER vẫn INITIAL_COUNTER, không bị phân loại renewal. Duplicate receipt normalized, missing provenance, wrong binding, refund hoặc overlap làm candidate từ chối.

V1–V13 giữ nguyên bytes/checksum; original V7 export private từ pin558fb03, không sửa/renumber và không vào default locations. Private fresh history quan sát đủ1–14; **13published Flyway checksums đều khớp**, V7 `-349926232`, candidate V14 `-753147948`. Version14/đường phát hành chưa được thống nhất với DB owner. Existing Core history1–6,8–13 chỉ append14, không tự chèn7/out-of-order. Không sửa history/repair/clean/baseline để qua kiểm tra.

## Kết quả thực chạy mới

| Nhóm | Kết quả | Phạm vi |
|---|---|---|
| Migration/real JDBC-service harness | **196 passed,0failed/skipped**,13scenarios | PostgreSQL17.12 mới, JDK21. Không phải196JUnit hoặc196API tests. |
| Selected JUnit regression | **79 passed,0failed/errors/skipped**,6suites | RenewalDates10, RenewalRequest15, InitialMembershipGuard8, BookingEligibilityValidator22, ServiceEligibilityValidator12, MembershipService12. Không cộng196và79 thành một suite. |
| Inventory SQL |3private targets,9checks,0failed|Dense history1–14; Core gap7→14; V7-only thiếu provenance. READ ONLY, fingerprints không đổi, sai database bị exit3.|
| Guard negative |2đạt|Unknown SQL và wrong full container ID bị từ chối trước resource change.|
| Clean checkout |Đạt|Candidate2SQL exact hashes, LF pin, published inventory, PS parser và Node parser; không credentials/manifest/build/research copy.|
| Cleanup |2lần đạt|69private DBs gồm các debug attempts;909registered PK rows, sentinel ngoài ledger giữ nguyên; không phải69scenario acceptance.|

13scenarios: fresh; V1–V6 có2payment periods; V7 ACTIVATION+RENEWAL; Core rehearsal đã có quotes/events/activation state; Core có coarse aggregate cũ; conflicting evidence; M03 trướcV11; duplicate normalized receipt; missing coverage; missing payment provenance; REFUNDED; wrong member/payment binding; overlap/rollback V14. Counts/check labels trong JSON, không cộng các attempt lỗi hoặc lượt168checks trước vào196.

Regression trên candidate kiểm actual M03/Renewal services với PostgreSQL/transaction manager: COUNTER+receipt/snapshot nguyên tử; original retry; PENDING không đổi hạn; đổi giá/duration/inactive plan sau quote vẫn dùng snapshot; duplicate SUCCESS không thêm kỳ; hai SUCCESS độc lập đồng bộ barrier và nối tuần tự; FAILED không cấp quyền; SUSPENDED khi nhận tiền giữ RECONCILIATION_REQUIRED; ownership; Member/Booking không bị migration sửa. Booking/D01 validator dùng canonical rows thật, leap-day inclusive và gap không được lấp. Injected M03 failure rollback Membership/payment/receipt/audit; V14 source conflict rollback archive/import/history ở bước đó.

Giữ mọi original business row/column value qua upgrade; restore payment columns không đổi original updated_at. V7 receipt vẫn đọc lại đúng, không bịa transaction; global reservation chặn M03 tái dùng receipt cũ. Coarse V11 aggregate được lưu JSON đầy đủ trước thay bằng source granular; snapshots legacy thiếu name/quote/currency vẫn NULL, không lookup giá plan hiện tại để backfill. Các activation counter state có dữ liệu được so trước/sau, không chỉ so bảng trống.

## Evidence và các lỗi đã sửa

Source hashes6executable files và matrix14versions nằm trong JSON. Sau lượt196chỉ bỏ trailing whitespace một dòng Java harness; token stream không đổi, lưu riêng tested/reviewed SHA256. Không chạy lại full chỉ vì whitespace/commit. Không thay executable production Java/POM/Dart, default profiles/gates hoặc published SQL. Full1106/R02 là evidence lịch sử, **không chạy lại/không gọi là kết quả DB01**. Không HTTP/UI E2E, Flutter build/test, camera/identity/liveness/accuracy mới trong task này. Tools/image/dependencies dùng cache; không cold install.

Các lỗi trong candidate/harness đã sửa trước lượt cuối: cast regclass thiếu guard, alias SQL; so sánh snapshot map có bảng mới trống và UUID/string JSON; overlap trả refusal code ổn định thay phụ thuộc UUID import order; psql17 `quit` không trả exitcode như dự kiến nên target guard dùng read-only exception+ON_ERROR_STOP. Attempts lỗi giữ private, cleanup theo authority riêng, không dùng repair/reset/reseed để biến thành pass.

Cleanup dùng sealed PK ownership, không broad delete/truncate/drop.5debug attempts đầu thiếu ledger được phục hồi ownership chỉ sau kiểm authority/resource/initial-empty proof, trước sentinel; không cơ chế fallback tự nhận dữ liệu ngoài fixture. Cleanup2lần đều giữ sentinel hash; sau đó chỉ xóa đúng UUID sentinel task tạo. Đã dừng đúng container DB01, giữ volume/schema/Flyway history; không động container/DB/resource khác.

## Còn thiếu trước rollout

1. Inventory **từng DB đích thật**, V7/V8+ applied status/checksum/installed rank, backup có payment dates/receipt, source mapping và owner approval; hiện UNKNOWN. Không giả V7 chưa áp trên máy đồng đội.
2. Thống nhất slot14, callback deployment/maintenance mode và forward-upgrade cho từng history. Chỉ thêmV14 sauV11 **không** sửa được cột thiếu trướcV11; phải dùng compatibility trước pending migrations. Candidate không là canonical release mặc định.
3. Refund cần đối soát nghiệp vụ nếu target có REFUNDED; candidate giữ dấu tiền và từ chối, không tự quyết định thu hồi/cộng quyền. Thiếu historical quote/date/receipt source không thể lấy từ plan hôm nay.
4. M04 legacy name fallback có thể sai khi current period plan khác memberships.plan_id và không name snapshot. Cần sửa read mapping đúng UUID/tên hiện tại, không bịa historical snapshot. V7 consumers chỉ hiểu2source cũng cần inventory vì view có LEGACY cho dữ liệu không có quote. Chưa mở production để che các giới hạn này.

**releaseReady=false**; hai đường đã rehearsal đạt không thay thế inventory/rollout approval DB chung. Face thật tiếp tục default-off/F03B dataset đang hoãn; simulator dev/test, chưa gateway/refund.
