> Snapshot đề xuất trước phê duyệt, giữ để truy nguồn. Những phần Member ACTIVE, actor-bound key, receipt case-sensitive/ngày/giá chưa chốt đã được thay bằng [quyết định M-03](../decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md). Candidate trong thư mục này không chạy; V9 rehearsal ở location riêng.

# M-03 Admin ghi nhận thanh toán quầy và kích hoạt Membership lần đầu

**Bản thiết kế để duyệt; chưa triển khai API, migration hoặc UI M-03.** Base `92328e0b6a81134921e77e6545b2d5bc02d6d622`, branch `research/admin-initial-membership-activation`, ngày 23/11/2026. Mọi lựa chọn dưới đây còn **PROPOSED**, chưa phải quyết định nghiệp vụ. Không sửa Booking, account creation, OTP hoặc default activation.

## 1 Nguồn và trạng thái thực tế

- Topic11 gốc (tệp bàn giao ngoài Git: `Topic11_FITCENTER.docx`), SHA256 `5e2164806b4927390e986712e04d53bee09255a3eac9ab33997bc4ff6f6a47b5`: PD-03/P0118–0119, UC-20/P0322–0352, catalog/P1002–1005. P là thứ tự paragraph OOXML, không phải số trang. P0100 nói Chương 3–7 là design proposal. UC-20 yêu cầu Admin/offline payment/evidence, start/expiry/status; enrollment retry không làm mất membership. Task đã thu hẹp thành Member **đã tồn tại**, không lặp tạo User/profile của M-02.
- [V2](../../../database/migrations/V2__membership_payment.sql): DATE nullable khi PENDING_ACTIVATION; tối đa một row chưa CANCELLED/Member; NUMERIC(12,2); global UNIQUE provider_ref; payment.period_start/end còn nguyên. [V6 audit](../../../database/migrations/V6__audit_log.sql) có actor/action/entity/details/correlationId. Chưa có bảng chứng từ quầy/idempotency.
- Bốn khảo sát22/11 vẫn được bảo toàn ngoài Git; đối chiếu [trạng thái Core hiện hành](../evidence/R01_MAIN_INTEGRATION_READINESS.md) và [migration candidate I01](../decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md) từ nguồn tracked. M-01/M-02/M-04 nay đã có, không dùng trạng thái thiếu trong snapshot22/11 làm kết luận hiện tại.
- [AdminAccountService](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/AdminAccountService.java) tạo DISABLED User+profile, không membership. **Chưa có MEMBER activation/credential flow**. M-03 không được tự ACTIVE hóa User hoặc bàn giao mật khẩu. UC-20 postcondition account ACTIVE chưa hoàn thành chỉ nhờ Membership ACTIVE.
- [M-04](../evidence/M04_MEMBER_MEMBERSHIP.md) đã commit/push92328e0: Member đọc array UUID/planName/startDate/endDate/status. Không current/next/payment history. Chưa có PaymentTransaction Java writer hoặc counter command.
- Fetch23/11: `origin/feature/database-schema` vẫn **558fb03fd5927ca9e04d17b54fd46e429fe62bb5**. V7 nằm nested `database/database/migrations/V7__membership_periods.sql`. Canonical V1–V6 và hai cây V1–V6 ở ref đó khớp Git blobs. Inventory12origin refs biết versions1–8, không thấy9; không chứng minh version chưa công bố của đồng đội. [Provenance](2026-11-23_M03_SOURCES.json).

## 2 Contract đề xuất

### Command

`POST /api/v1/admin/members/{memberId}/activate-membership`

Chỉ ADMIN ACTIVE; actor từ principal, recheck sau chờ khóa. `memberId` là **members.id/profileId**, không users.id. Không tạo Member/PT, không nhận actor/status/UUID membership/timestamps từ client.

Header `Idempotency-Key`: UUID mới cho một ý định ghi nhận, giữ nguyên khi đối chiếu/retry có chủ đích. Body minh họa tổng hợp:

```json
{
  "planId": "11111111-1111-4111-8111-111111111111",
  "amountCollected": 500000.00,
  "receiptRef": "DEMO-2026-0001",
  "note": "Dữ liệu minh họa tổng hợp"
}
```

Plan chọn UUID từ GET plans ACTIVE, không tìm theo tên. Amount là JSON number đọc bằng BigDecimal, >=0, NUMERIC(12,2), không silently round hoặc nhận string/bool/overflow. Receipt nonblank<=100 codepoints, note optional<=500 là giới hạn **candidate mới**, không nói V2 đã có các cột này. Reject unknown/duplicate fields theo convention M-01. Không nhận startDate/endDate/paidAt/currency trong phương án server-today/single-VND; phải đổi contract nếu người dùng chốt lựa chọn khác.

**Ngày/giá đề xuất chưa duyệt:** Clock sau khóa → ngày Asia/Ho_Chi_Minh; start=today; expiry=start+durationDays−1 inclusive. N=30, start23/11/2026→end22/12/2026; không quy tháng=30ngày. Chốt plan ACTIVE, price/duration snapshot lúc ghi nhận; phase đầu amountCollected=giá plan, không discount/prorate. Giá0 của plan đã hợp lệ theo M-01; cách ghi phiếu thu0 cho activation cần xác nhận, không tự bắt price>0. Đơn VND cần được chốt vì V2 chưa lưu currency.

**Eligibility đề xuất chưa duyệt:** account Member ACTIVE, profile hợp lệ, chưa từng có membership. PENDING có sẵn hoặc lịch sử CANCELLED/EXPIRED/SUSPENDED/ACTIVE trả conflict để không biến initial activation thành renewal/reactivation. Cần chốt có reuse PENDING hay không; đây không phải rule đã có trong Topic11. Không đổi User.status.

### Response và đọc đối chiếu

Lần ghi nhận đầu **201**, DTO trực tiếp theo conventions hiện tại:

| Trường | Nội dung |
|---|---|
| activationId, requestId, memberId | Receipt-record UUID server, UUID Idempotency-Key, Member profile UUID |
| membership | DTO M-04: id,planId,planName,startDate,endDate,status=ACTIVE tại activation |
| payment | id,provider=COUNTER,providerRef server,amount,status=SUCCESS,processedAt UTC |
| receipt | receiptRef,note,confirmedByUserId,confirmedAt UTC |
| planSnapshot | name,durationDays,listedPrice,currency theo quyết định tiền tệ |

confirmedAt là lúc Admin ghi nhận, **không giả là giờ tiền thực sự đã được thu**. DATE thuần lịch, timestamps ISO UTC, UI giờ Việt Nam. Snapshot response bất biến cho retry và GET chứng từ mô tả kết quả lúc ghi nhận, không quảng bá là trạng thái tài chính hiện tại sau refund/correction tương lai. M-04 vẫn phản ánh effective status hiện tại, không bị đổi semantics thành snapshot lịch sử. Không credentials/PII dư thừa.

Read đề xuất chưa có trong source: `GET /api/v1/admin/members/{memberId}/membership-activation`, ADMIN ACTIVE, 200 cùng snapshot committed đầu tiên, 404 ERR_NOT_FOUND nếu chưa thấy. Tối đa một initial receipt/Member trong phương án này. Không mở quyền Member `/memberships/me` cho Admin. GET404 khi POST còn in-flight **không chứng minh POST thất bại**, cũng không chứng minh Member chưa từng có membership legacy. Timeout phải GET đối chiếu; chỉ retry có chủ đích cùng key+body, không tự replay/key mới. Read này phục vụ đối soát, không endpoint test; cần duyệt cùng command.

### Error codes dự kiến

Dùng [ApiErrorResponse](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/error/ApiErrorResponse.java): `{success:false,error:{code,message,details,correlationId},timestamp,status,message}` và X-Correlation-Id. Không lộ SQL/stack trace. Mã domain mới dưới đây **chưa được implement**:

| HTTP | Code | Điều kiện |
|---|---|---|
|401|ERR_UNAUTHORIZED|Không/invalid token, convention hiện có|
|403|ERR_FORBIDDEN|Sai role/Admin không ACTIVE hoặc bị khóa lúc chờ|
|400|ERR_VALIDATION|UUID/header/body/type/scale/range/blank/length/unknown field sai|
|404|ERR_NOT_FOUND|Member/plan không tồn tại, hoặc GET chưa thấy committed activation|
|409|ERR_MEMBER_ACCOUNT_NOT_ELIGIBLE|Member account không thỏa rule được duyệt|
|409|ERR_MEMBERSHIP_ALREADY_EXISTS|Không phải initial activation theo scope được chọn|
|409|ERR_PLAN_NO_LONGER_AVAILABLE|Plan inactive khi xử lý|
|409|ERR_AMOUNT_MISMATCH|Giá/thực thu không khớp trong phương án chưa cho chênh lệch|
|409|ERR_RECEIPT_ALREADY_USED|Receipt key đã dùng bởi command khác|
|409|ERR_IDEMPOTENCY_KEY_REUSED|Key trùng nhưng khác actor/member/payload|
|409|ERR_CONFLICT|Lock timeout/concurrency chưa phân loại; GET đối chiếu|
|500|ERR_INTERNAL|Lỗi bất ngờ, rollback, không giả success|

Không coi mọi unique violation là receipt duplicate. [WebConfig](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/WebConfig.java) hiện chỉ allow Authorization/Content-Type/X-Correlation-Id: cần thêm đúng Idempotency-Key và expose Idempotency-Replayed nếu client đọc, giữ exact origins. ApiClient hiện nhận một expectedStatus: cần hỗ trợ chính xác200/201 cho command này, không nới status của writes cũ. Chưa sửa code trong lượt chuẩn bị.

## 3 Transaction và idempotency

Đề xuất READ_COMMITTED, bounded timeout như writers hiện tại. Membership+payment+receipt+audit cùng transaction; không side-effect mail/gateway/Face. Đây là ghi nhận khoản đã thu offline, không thu tiền qua ngân hàng.

1. Validate JSON/key, resolve ADMIN/Member identity; không dùng entity resolve trước khóa để quyết định điều kiện mutable.
2. Khóa **Member FOR NO KEY UPDATE trước membership** theo [MemberRepository](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/repository/MemberRepository.java); mutex tồn tại cả khi chưa có membership. Không payment→Member hoặc PT/slot/booking/policy lock.
3. Sau Member lock, lookup idempotency record. ADMIN phải ACTIVE mọi lần. Cùng key+actor+Member+canonical payload → **200**, `Idempotency-Replayed:true`, cùng response snapshot; không tạo dòng/audit thành công thứ hai, không dùng giá/ngày mới thay kết quả cũ. Key khác payload/actor/target →409. Replay chỉ đọc receipt đã commit, dù Member/plan sau đó đổi trạng thái.
4. Command mới: đọc/khóa lại memberships theo ID nếu có nhiều CANCELLED; kiểm eligibility đã chốt. Candidate không ghi đè/reuse row. Khóa đọc plan sau Member/membership để snapshot nhất quán; không plan→Member. Scalar recheck actor/target sau waits, tránh JPA stale entity; không thêm User write/lock ngược vào command này. Account status race giữ convention recheck của writers hiện có.
5. Lấy Clock **sau lock waits**, tính DATE/instant. Kiểm ngày có thể lưu trong PostgreSQL/LocalDate, duration int32 không wrap hoặc silent clamp; arithmetic không representable trả lỗi validation có kiểm soát, không business cap mới.
6. Insert Membership ACTIVE; V2 payment SUCCESS/provider COUNTER/provider_ref `counter:<server UUID>`, amount thực thu đã đối chiếu, period_start/end cùng ngày activation và processed_at=confirmedAt. Insert receipt/fingerprint/snapshot, V6 audit USER/action `MEMBERSHIP_INITIAL_ACTIVATED`, entity membership, IDs/amount/dates/correlationId không secrets. Flush trước201.
7. Conflict index do Member khác: rollback **toàn transaction**, giải phóng locks rồi lookup trong **transaction mới** để phân loại. Không query tiếp trong PostgreSQL transaction đã aborted. Chỉ replay khi tìm đúng committed key/actor/fingerprint; resolver không retry write.

Fingerprint SHA256 gồm command/version,actor UUID,Member profile UUID,plan UUID,amount decimal normalized,receiptRef và note normalized. Không gồm ngày/giá plan hiện tại: retry qua nửa đêm/plan đổi vẫn nhận kết quả cũ. Đề xuất strip whitespace ngoài, giữ case/nội dung receipt; null/blank note normalize trước hash. Không cache Redis/TTL xóa idempotency tài chính. Key global UUID; uniqueness chứng từ độc lập key.

Hai Admin cùng Member → tối đa một initial activation; Member khác cùng receipt → tối đa một receipt, loser rollback. M-03 nối thứ tự R03/R04 Member→membership, không đi tiếp PT/slot nên không tạo vòng khóa Booking. Plan writer tương lai không được giữ plan rồi quay lại Member mà chưa review thứ tự khóa.

## 4 Dữ liệu chứng từ và migration đề xuất

**Phương án A để duyệt:** reuse V2 payment_transactions cho khoản quầy SUCCESS và giữ period_start/end; thêm **một bảng** membership_initial_activations cho receipt/idempotency/snapshot. Thêm hai unique key kỹ thuật làm đích composite FK, không thay giá trị cũ. [DDL candidate](M03_COUNTER_ACTIVATION_SCHEMA_CANDIDATE.sql) chỉ dưới docs, không tên Flyway, chưa áp/SQL-test.

- Receipt UUID; Member/membership/payment links đúng owner; unique Member/membership/payment cho một initial operation trong phạm vi đề xuất.
- Key UUID unique, fingerprint64, response_snapshot JSONB chỉ DTO. Giá niêm yết/duration snapshot giữ giá trị lúc ghi nhận; amount/dates/plan ở payment liên kết. Snapshot response bất biến cho retry.
- Receipt ref nonblank100, unique toàn một Fitness Center **chưa chốt**; actor/time server, note500, currency VND đề xuất. Checkbox không thay chứng từ persist; không tự tạo mã phiếu, giờ thu tiền, upload ảnh hoặc legacy evidence giả.
- Composite FKs bắt receipt owner/membership khớp payment. Service còn phải kiểm ACTIVE ADMIN, matching plan/SUCCESS/date/amount: CHECK không đọc bảng khác. Chưa thêm business trigger khi rule chưa chốt. Không endpoint sửa/xóa receipt; test cleanup reverse FK theo UUID.
- SUCCESS đã có trong V2; COUNTER hợp provider VARCHAR30. Việc tạo counter transaction là lựa chọn lưu trữ kỹ thuật, **không phải Topic11 bắt buộc** phải có online tx cho offline payment.

**Khác V7 phải đồng bộ:** V7 draft ACTIVATION cấm payment_transaction_id; RENEWAL đòi tx SUCCESS. Phương án A có counter payment riêng nhưng không backfill nó thành RENEWAL chỉ vì SUCCESS. Khi chuyển periods: map receipt→ACTIVATION, giữ receipt→counter payment linkage ở bảng này. Nếu muốn gắn tx trực tiếp ACTIVATION, cần thiết kế migration chưa áp được duyệt/forward plan hợp lệ. Phương án B là adopt period model an toàn trước M-03, không counter tx cho activation; scope lớn hơn. Không trộn hai model âm thầm.

### Bảo toàn periods V2 và V7

V7 tại558fb03 DROP ck_payment_period,period_start,period_end ngay đầu, **không archive/backfill**. Sau đó tạo periods/constraints/triggers/view; memberships cũ không có period tương ứng. Trigger INSERT-only không bảo đảm immutable/aggregate. V7 đổi nghĩa memberships.plan_id thành plan mua gần nhất, khác current plan. M-04/R03/D01 đang đọc aggregate V2; không đổi meaning mà chưa cập nhật contract/tests. POM chỉ canonical root1–6; nested V7 không tự chạy.

Candidate M-03 chỉ ADD bảng/keys, không backfill legacy payment bằng receipt/Admin giả. ADD UNIQUE cần dựng index và giữ khóa DDL: rehearsal phải đo lock/time trên bản sao có lịch sử, không tuyên bố online migration không gián đoạn. Nếu quy mô buộc index concurrent nhiều bước, review kế hoạch Flyway transaction riêng trước release. Rehearsal sau này phải giữ nguyên IDs/owner/status/amount/provider_ref/processed_at/**period_start/end** cho mọi payment cũ, kể cả SUCCESS/REFUNDED/PENDING/FAILED/CANCELLED/NULL membership link. Period migration tổng thể là việc riêng: giữ raw dates, phân loại missing/mismatch/overlap/refund; không chia aggregate bằng duration plan hiện tại. REFUNDED đã từng credit có thể cần giữ kỳ; V7 trigger chỉSUCCESS chặn naïve copy, không tạm đổi status để lách.

**V9 chạy sau không chữa được DROP V7.** Nếu V7 chưa từng áp ở release target: giữ ngoài canonical tới khi có bản expand-only/bảo toàn dữ liệu được duyệt; chỉ sửa migration được xác nhận chưa áp. Nếu V7 đã áp nơi khác: cần inventory/checksum/backup/recovery và forward plan, không sửa checksum cũ. Thêm cột trống không phục hồi dates mất. Chưa có Java Payment entity không có nghĩa DB không có lịch sử. Không seed lại/clean/repair/history edits. Không biết history DB chung là blocker release, không cần kết nối DB chung để hoàn thành thiết kế này.

### Version và V8 rehearsal

Slot **V9 mới là tentative**, chưa đặt canonical;12 origin refs hiện biết1–8, không thấy9, không bảo đảm version chưa công bố. V8 chỉ location activation-rehearsal, default false/503; M-03 không cần OTP schema/profile.

- Test độc lập sau quyết định có thể dùng **DB mới riêng** V1–V6+candidate9 ở location M-03 rehearsal guard riêng; ghi đây là history test, không release. Không thêm9 vào DB1–6,8 cũ rồi tuyên bố release ready. Chưa tạo DB/runner/profile mới trong lượt chuẩn bị.
- Release từ DB mới/bản sao history thực, theo thứ tự canonical đã chốt: ví dụ1–6→V7 an toàn đã duyệt→V8 nếu được release→V9. Nếu còn V7 destructive hiện tại thì dừng phát hành, không áp chỉ để đủ thứ tự. Phân biệt candidate chưa áp/rehearsal với version đã áp, không đổi history/checksum tại chỗ.
- Cả history1–6,8 và1–6,9 gặp V7 đến muộn sẽ bị từ chối khi outOfOrder=false; không bật out-of-order/ignore-pattern/repair. Rehearsal không phải chứng nhận upgrade release. [Quyết định V8](../decisions/2026-11-22_PT_ACTIVATION_REHEARSAL.md) giữ nguyên.

## 5 Vị trí Admin UI và read-back M-04

Giữ [Admin Home](../../../frontend/fitcenter_ad/lib/screens/home_page.dart), card **Kích hoạt Gói hội viên** đang ComingSoon. Khi triển khai nối [InitialActivationPage gốc](../../../frontend/fitcenter_ad/lib/screens/initial_activation_page.dart), giữ layout/theme/card sections, không dashboard mới. Trên AccountsPage chỉ đề xuất action riêng cho Member có profile, dẫn vào page bằng profileId; không gộp với Thêm tài khoản, PT không có action này.

Form chọn Member từ GET Admin list có sẵn (readonly identity/profile UUID), chọn plan UUID từ GET ACTIVE, nhập actual amount/receipt/note/confirmation. Bỏ months/client date/local success và Face simulation khỏi luồng vận hành. Chỉ201 hoặc verified replay200+DTO hợp lệ mới ghi nhận thành công. Không thêm current/next/payment history vào M-04.

Session memory/epoch/modal/busy giữ conventions. Tạo key một lần trước gửi; kết quả chưa rõ giữ key/body để GET reconcile, không auto POST qua refresh/mạng. Logout bỏ modal/data/response phiên cũ, không gửi pending command bằng account khác. Reload mất memory: GET Admin theo Member để đối chiếu; không tìm theo tên plan. Header/CORS/client200/201 phải được test.

Demo dự kiến: **fixture** MEMBER ACTIVE chưa có membership → Admin UI command → PostgreSQL cùng receipt/payment/membership UUID/dates/amount → Member login/M-04/reload-login thấy đúng membership UUID/values. Không gọi đây là đã làm MEMBER activation. Account DISABLED tạo từ M-02 chưa đăng nhập được cho tới khi có quyết định/flow credential MEMBER, không SQL-setACTIVE rồi gọi là nghiệp vụ đã triển khai.

## 6 Kịch bản nghiệm thu sau quyết định

Tất cả dưới đây **PLANNED, chưa chạy**. JDK21/PG riêng, source hashes executable cuối; seed/cleanup UUID, không DB chung. Backend focused→full vì có Java writer; focused là subset. Admin client/widget/analyze/build; Member chạy khi đổi code/rủi ro contract; HTTP/DB/UI tách counts.

| Nhóm | Kịch bản và oracle |
|---|---|
| Quyền/identity | ADMIN ACTIVE;401/invalid token;MEMBER/PT403;Admin bị khóa trước/sau chờ;users.id thay profileUUID không tác động nhầm Member;target account theo rule được duyệt |
| Contract | UUID/key/body missing/null/type/unknown/duplicate fields;amount0/negative/scale/range;NUL/blank/Unicode length receipt/note;không mass assignment server IDs/status/dates/actor |
| Initial | No membership→201,cùng membership/payment/receipt/audit rows;User/profile/Booking/slot không đổi;plan missing/inactive;PENDING/history xử lý theo quyết định |
| Ngày/giá | Clock VN hôm nay/nửa đêm khi đợi khóa;N=1/30/leap/expiryinclusive;int32 arithmetic không wrap;plan0/staleprice/variance;plan đổi giữa chọn và xử lý;không tháng lịch |
| Retry/idempotency | Cùngkey/canonicalbody→200/cùngsnapshot/UUID,one payment/receipt/audit;decimal500000/500000.00 giống;khácbody/actor/Member409;retry sau plan đổi/VN midnight không đổi kỳ;lost201→GET→explicit same-key replay |
| Receipt duplicate | Cùngreceipt/key khác/cùng hoặc khácMember→một committed receipt;case/space/namespace theo rule duyệt;receiptRef khác providerRef;không double-credit |
| Concurrency thật | Barrier/latch+PGlock wait cho2Admin cùngMember/cùngkey/cùngreceipt khácMember,plan/account đổi;chỉ1activation,controlled409/no500,không chỉ requests tuần tự |
| Booking/D01 races | Member lock phối hợp R03/R04;không sửa Booking service/state;D01 REPEATABLE_READ thấy snapshot trước commit hoặc mới sau commit,no half-state |
| Rollback | Fault sau từng insert membership/payment/receipt/audit;unique/timeout/deadlock rollback toàn bộ;retry sau rollback tạo1lần;resolver dùng TX mới sau abortedTX |
| Schema/history | DBtrống vàV1–V6 có legacy SUCCESS/REFUNDED/PENDING/FAILED/CANCELLED/NULLlinks/DATE boundaries;exactbefore/after hashes;wrongowner/compositeFK fail;lateV7 bị từ chối;Flyway DDL rollback |
| Admin UI | Loading/empty/error/validation,busy,modal/logout/in-flight response;201/200validDTO;409reload;networkunknown GET/noautomaticPOST;theme/navigation gốc |
| M-04 UI + DB | ACTIVEfixture A nhận UUID/plan/date/status sau Admin command,reload/login vẫn đúng;B không thấyA;expiry inclusive và status server;không gọi là MEMBER activation/gateway E2E |

DoD: chốt quyết định→API/OpenAPI đúng endpoint triển khai→schema test riêng và history preservation→HTTP/DB/concurrency/rollback→UI Admin+M-04 thật→evidence cuối/cleanup. Chưa quyết định/chưa chạy không gọi M-03 hoàn thành.

## 7 Quyết định còn thiếu và blocker

| ID | Nguồn đã có | Cần chọn | Đề xuất chưa chốt | Ảnh hưởng |
|---|---|---|---|---|
| M03-DATE | UC-20 start/expiry;D01 DATEVN/inclusive đã chốt | Servertoday hayAdmin chọn;lateposting/backdate/future? | Server todayVN,N ngày=end=start+N−1;confirmedAt là giờ ghi nhận | request/date/tests |
| M03-PRICE | V2/M01 price>=0,ngày,NUMERIC12,2 | Chênh thực thu/niêm yết,quote time,currency,phiếu0? | Snapshot server lúc thực hiện,phase1amount=price,VND;không tự bắt price>0 | money/snapshot/UI |
| M03-RECEIPT | UC20 offline evidence;V7receipt100/amount/admin/time làproposal | Unique toàngym haytheonăm/sổ?case/space?ngày phát hành/file? | Nonblank100,stripngoài/giữcase,uniquegym;note500,noattachmentphase1 | keys/fingerprint/fields |
| M03-ACCOUNT | M02 DISABLED;PTOTP không áp MEMBER;UC20 accountACTIVE | M03 chỉ nhận ACTIVEexisting hay activateUser?Credential flow nào? | Tách account activation,phase1ACTIVEexisting;không âm thầm đổi User.status | **blocker newaccount→Memberlogin M-04** |
| M03-FIRST | Initial cho Memberexisting;V2 cóPENDING/history | Reuse PENDING?CANCELLED history có còn gọi initial? | Slice đầu chưa có membership;không ngầm renew/reactivate | eligibility/uniques |
| M03-MODEL | V2txperiods;V7 ACTIVATIONkhôngtx làdesign | CounterSUCCESS+receipt(A) hayperiod-only(B)? | A nhỏ hơn,giữV2periods;backfill phân loại COUNTER rõ | schema/history |
| M03-API | TopicPOST;thiếuAdmin read reconcile | GET record/key/replay201→200? | GETAdminbyMember+key UUID,cùngkey/body explicitretry | CORS/client/OpenAPI |
| RELEASE | V7DROPchưabackfill,V8separate,versions1–8 đã thấy | Version/path/order/checksum ở môi trường chưa công bố? | V9tentative;testDBmới và release ordered plan,khôngrepair/outOfOrder | **release**, không chặn tài liệu/test độc lập được giao |

Không hỏi lại Booking/early renewal/refund/price0 plan đã có nguồn. Không cần chờ Duy để tiếp tục thiết kế/test độc lập được giao; cần đồng bộ version/order/model trước release. Không coi comment nhánh DB là business approval, không liên hệ người khác ở lượt này.

## 8 Công việc thực sự đã làm

Đã đọc spec/code/UI/schema, fetch+inventory12refs, so V1–V6 Git blobs, review V7/V8, viết draft contract/DDL/tests. **Không chạy JUnit/Flutter/HTTP/UI/SQL/Flyway**, không start DB/backend/mail, không apply migration. M-04 Member52/UI19/HTTP14/DB10 và Backend801 rehearsal là evidence lịch sử, không phải kết quả M-03. Bốn research22/11 và Face giữ nguyên. Chỉ docs chưa stage/commit/push/merge. [PROJECT_STATUS](../../PROJECT_STATUS.md) ghi bước tiếp theo.
