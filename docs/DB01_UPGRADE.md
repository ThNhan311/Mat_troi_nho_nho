# DB-01 — Compatibility candidate V7 / Backend Membership

**Candidate đã thử trên DB riêng; chưa được dùng cho DB chung hoặc production. `releaseReady=false`.** [Evidence](backend-handover/evidence/DB01_MIGRATION_COMPATIBILITY.md), [source manifest](backend-handover/proposals/db01/candidate-manifest.json), [R01 phát hiện](backend-handover/evidence/R01_MAIN_INTEGRATION_READINESS.md), [portable setup](INTEGRATION_SETUP.md).

## Đích và inventory bắt buộc

Chưa có DB chung nào được xác định/cho phép kết nối trong DB-01. Không coi history private của người phát triển là history máy đồng đội. Owner chuẩn bị **một output riêng cho từng DB thực tế**:

| Mục | Trạng thái DB chung hiện tại |
|---|---|
| Nhãn môi trường, host/port/database, owner, quyền inventory | Chưa xác định; không tự điền localhost/DB demo vào đây |
| V1–V14 installed rank/version/script/checksum/success | UNKNOWN, đặc biệt V7 và V8+ có thể đã áp |
| Backup trước V7, payment period columns/rows và chứng từ quầy | UNKNOWN |
| `membership_periods`/paid-periods/quotes/events/activation state thực tế | UNKNOWN |
| Code/role đang ghi hoặc đọc period model V7 | UNKNOWN; cần dừng writers trước upgrade |
| Collation/locale, extensions, phiên bản PostgreSQL và backup restore đã thử | Chưa inventory |

Dùng [SQL chỉ đọc DB01](../database/tools/db01-read-only-inventory.sql). Script bắt buộc expected database/role, REPEATABLE READ READ ONLY, timeout10s, catalog/aggregates; sai/thiếu đích phải exit nonzero. Không in email, OTP/grant, template, receipt cụ thể hoặc từng payment. Output giữ private, owner review trước chia sẻ.

```powershell
# Owner đã xác định/cho phép đúng đích; không chạy lệnh này lên DB chưa biết.
$env:PGHOST = Read-Host 'Approved DB host'
$env:PGPORT = Read-Host 'Approved port'
$env:PGDATABASE = Read-Host 'Approved database'
$env:PGUSER = Read-Host 'Approved read-only role'
$privateOutput = Read-Host 'Private output path outside Git'
# Password qua pgpass/local secret manager; không đặt trong command line/báo cáo.
psql -X -v ON_ERROR_STOP=1 -v "expected_database=$env:PGDATABASE" -v "expected_role=$env:PGUSER" `
  -f database/tools/db01-read-only-inventory.sql -o $privateOutput
```

DB-01 chỉ đã chạy SQL này trên3DB test do task tạo, không chạy các lệnh trên tới DB chung.

## Nguồn dữ liệu chuẩn đề xuất

**`membership_paid_periods` là nguồn kỳ cấp quyền duy nhất.** Payment là nguồn sự kiện tiền; M03 receipt/idempotency và renewal quote/event là chứng cứ/snapshot. Payment SUCCESS có thể RECONCILIATION_REQUIRED và không tạo kỳ; không suy SUCCESS luôn đồng nghĩa được cấp quyền. `memberships` giữ owner/status và aggregate phục vụ API, không thay thế kiểm coverage từng kỳ.

| Nội dung | Model V7 | Model Backend hiện hành / cách chuyển |
|---|---|---|
| Dates | `period_start/end`, inclusive | `start_date/end_date`, inclusive; giữ UUID/date/plan của kỳ V7; không đổi DATE sang UTC |
| Initial quầy | ACTIVATION, không payment FK; amount/actor/time/receipt | M03 ghi COUNTER SUCCESS + receipt/snapshot + INITIAL_COUNTER nguyên tử. **Không tự tạo COUNTER payment hoặc M03 response cho ACTIVATION cũ.** Giữ bản gốc và map vào LEGACY_AGGREGATE có provenance, không biến thành renewal |
| Giá/thời lượng/tên/currency snapshot | V7 không đủ snapshot, plan có thể đã thay | M03/quote snapshots giữ nguyên; source legacy thiếu để NULL. Không lấy plan hiện tại để dựng snapshot lịch sử |
| Renewal | SUCCESS payment FK, unique một payment/kỳ | Quote snapshot + events/idempotency + RENEWAL; giữ Member-first locking, không đổi plan hiện dùng thành plan tương lai |
| Receipt | V7 chỉ bắt buộc không blank, không global unique | Dự trữ key bằng chính Java normalizer M03 (NFC/strip/uppercase ROOT); duplicate legacy keys làm candidate dừng; M03 mới không dùng lại key legacy |
| Refund | V2 cho REFUNDED, V7 không định nghĩa thu hồi quyền sau refund | Candidate dừng `DB01_REFUND_RECONCILIATION_REQUIRED`; không tự xóa kỳ/cộng quyền/đổi thành FAILED. Cần quy trình đối soát riêng nếu target có rows này |
| Reconciliation | Không có fulfillment ledger tương đương | SUCCESS quote RECONCILIATION_REQUIRED được giữ, không backfill entitlement; FAILED/CANCELLED không cộng kỳ |
| Paid coverage | V7 overview current/next/last end; không chứng minh toàn khoảng không gap | Booking/D01 dùng canonical period union; test gap và ngày nhuận/inclusive. Coarse aggregate của V11 chỉ thay khi có source granular; bản aggregate đầy đủ được archive |

V14 đổi tên bảng V7 thành `db01_legacy_membership_periods`, giữ mọi row/ID/receipt và chặn DML. Tên `membership_periods` trở thành view chỉ đọc trên canonical rows; `v_membership_overview` cũng đọc canonical. Không mirror hai writer, không trigger đồng bộ hai bảng period. Chỉ M03/Renewal tiếp tục ghi canonical trong transaction hiện có. `payment_transactions.period_start/end` được giữ cho code hiện tại như metadata tương thích, không là nguồn admission/coverage độc lập.

Các ledger `db01_period_sources`, `db01_payment_period_evidence`, `db01_receipt_evidence` giữ source JSON/links cho migration, không phải bảng period vận hành thứ hai. Mỗi phép map phải có source; xung đột dates/binding/receipt/overlap làm dừng, không chọn bản mới nhất bằng suy đoán. V11 coarse aggregate được giữ đầy đủ trong `db01_generated_aggregate_archive` trước khi thay bằng kỳ có nguồn; đây là row dẫn xuất V11, không xóa row lịch sử V7/payment/receipt.

## Hai đường upgrade và thứ tự

Không sửa V1–V13, không renumber/repair/history edits/clean/out-of-order. [V14 candidate](backend-handover/proposals/db01/migration/V14__unify_membership_period_read_model.sql) nằm ngoài default locations/POM; version14 **chưa được duyệt là release slot** khi chưa có shared inventory. [Compatibility SQL](backend-handover/proposals/db01/before-upgrade.sql) không giả là Flyway version: runner dùng callback rõ ràng, có transaction và ledger. Đây là deployment protocol phải được review, không chỉ chép thêm V14 vào thư mục migration.

**A. DB trống hoặc mới V1–V6, V7 chưa áp, latest<=6:**

1. Inventory/backup/maintenance mode, dừng toàn bộ writers/readers cũ. Fresh install chạy V1–V6 trước; không seed lại DB đã có lịch sử.
2. BEFORE_MIGRATE backfill các payment dates V2 vào evidence có payment UUID và source JSON; reject SUCCESS thiếu nguồn hoặc REFUNDED chưa đối soát. Toàn bộ dữ liệu bị DROP đã có nguồn giữ lại trước khi chạy V7.
3. Chạy **nguyên V7 pin558fb03**, checksum `-349926232`; chỉ trong private rehearsal đã backup/verify, không chạy V7 DROP không bảo vệ.
4. AFTER_EACH_MIGRATE(V7) phục hồi hai cột/constraint từ evidence **trước V8/V9/V11**. Chỉ tạm tắt timestamp-maintenance trigger V2 để bảo toàn updated_at, không tắt FK/CHECK; bật lại trong transaction. Java normalizer chuẩn bị receipt reservations.
5. V8–V13 nguyên bản, sau đó V14 hợp nhất read model; validate/checksum, đối chiếu source rows/dates/receipt/snapshot/coverage, mới xem xét mở application theo inventory đã duyệt.

**B. DB đã áp V7:**

1. Xác minh đúng Git source/checksum V7 và tất cả versions đã áp. Không áp lại V7. V7 location chỉ dùng resolve/validate history.
2. BEFORE_MIGRATE chạy trước mọi pending migration: phục hồi payment dates từ V7 RENEWAL có exact transaction/member/membership/plan binding, hoặc payment evidence/backup đã xác minh, hoặc M03 response snapshot có liên kết. ACTIVATION không payment không được gán bừa một payment cùng amount/ngày.
3. Thiếu source, conflicting evidence, wrong binding, duplicate normalized receipt, refund hoặc coverage không rõ thì dừng. Giữ DB/history; owner phải cung cấp backup/chứng từ có nguồn. Không suy ngày từ giá/duration plan hôm nay.
4. Sau compatibility mới áp pending V8–V13/V14 theo thứ tự, giữ applied checksum/history. V14 chuyển V7 rows sang source archive/read-only view và canonical read model.

**Rehearsal đã có V8–V13 nhưng chưa có V7:** append V14 trên nhánh history hiện hữu, **không chèn V7 muộn**. Test đường này đạt nhưng gap7 vẫn không là canonical release chain. Target V7 khác checksum, failed migrations, version14 đã dùng hoặc history khác phải được inventory/thiết kế riêng; runner này không tự sửa.

Mỗi compatibility step/migration có transaction; không tuyên bố một transaction bao phủ toàn bộ chuỗi Flyway. Nếu migration sau thất bại, giữ maintenance/default gates off, inventory trạng thái thực tế rồi khắc phục forward; không reset history. Tests kiểm rollback compatibility/V14/M03, không dùng clean/repair để chạy lại.

## Chạy rehearsal private có guard

Windows Docker Desktop Linux local, JDK21, Node/Python theo [portable prerequisites](INTEGRATION_SETUP.md). Ports127.0.0.1:15441 phải trống, image17.12 digest pin. Không dùng resource/credentials cũ hoặc shared DB.

```powershell
$jdk = Read-Host 'JDK21 directory'
$private = Join-Path $env:LOCALAPPDATA ('Temp/fitcenter-db01-'+[guid]::NewGuid().ToString('N'))
$runner = 'backend/scripts/db01-rehearsal.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Provision -JavaHome $jdk -PrivateDirectory $private
$id = (Get-Content "$private/account-resource.json" -Raw | ConvertFrom-Json).containerId
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Run -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Cleanup -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Cleanup -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -Action Stop -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $id
```

Run luôn tạo databases mới và sealed PK ownership ledger; không overwrite/reseed DB cũ. Logs, authority, credentials và UUID registries ngoài Git. Cleanup chỉ PK đã sealed, so fingerprints ngoài fixture, giữ Flyway/schema/volume. Legacy archive DML guard chỉ tạm mở trong cleanup test đúng resource/UUID rồi bật lại; không dùng cách này trong vận hành. Full ID/context/image/volume/namespace/role/datasource guard giữ nguyên. Exact candidate2SQL + published12SQL được kiểm, không tự nhận mọi SQL tìm thấy; candidate `.gitattributes` ghim LF để checksum portable. Không có profile production mới.

## Giới hạn trước release

- Chưa có inventory/backup/provenance DB chung; version/order14 và callback deployment cần thống nhất với Database owner. Không tự apply lên target chưa biết.
- M-04 `MembershipService.toResponse` hiện fallback tên từ `memberships.plan_id` khi legacy period không có name snapshot. Nếu current period plan khác FK aggregate có thể sai tên. Cần sửa lookup đúng plan UUID hiện dùng và mô tả rõ tên hiện tại không là snapshot lịch sử trước khi rollout các rows legacy này; DB01 không bịa snapshot để che lỗi, không sửa API/Frontend trong task.
- V7 view chỉ là read compatibility: legacy source thiếu quote dùng LEGACY/LEGACY_AGGREGATE, không cam kết binary-compatible với consumer chỉ nhận ACTIVATION/RENEWAL. Cần inventory/migrate các consumer cũ, cấm writer cũ.
- Không triển khai refund/gateway, production activation mail, Face admission hoặc migration phát hành. Không UI/E2E mới trong DB01; các runtime gates mặc định giữ nguyên.
