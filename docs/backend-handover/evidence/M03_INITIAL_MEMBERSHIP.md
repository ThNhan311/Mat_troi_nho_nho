# M-03 — Admin initial counter Membership,23/11/2026

Base M-04 **92328e0b6a81134921e77e6545b2d5bc02d6d622**, branch **feature/admin-membership-initial-activation**. Thử trên working tree trước commit; SHA commit cuối tra Git history. [Quyết định/contract](../decisions/2026-11-23_M03_INITIAL_MEMBERSHIP.md), [quickstart](../18_INITIAL_MEMBERSHIP_QUICKSTART.md), [OpenAPI](../api/openapi.yaml), [nguồn chuẩn bị](../proposals/2026-11-23_M03_SOURCES.json).

## Kết quả thực chạy

| Tầng | Passed | Failed/errors/skipped | Phạm vi |
|---|---:|---|---|
| Backend scoped full Maven/JDK21 | 832 | 0/0/0 | Default baseline + M-03 PG rehearsal; 2 opt-in PT PG suites không được chọn |
| Focused Backend | 62 | 0/0/0 | 54 HTTP+PG tests +8 guard tests, là tập con full |
| Admin Flutter client/widget | 89 | 0/0/0 | Focused16 là tập con, includes double-callback same-key guard |
| Member Flutter client/widget | 53 | 0/0/0 | M-04 readback/date parser expanded year |
| Chrome UI checks | 24 | 0/0/0 | API/DB thật, không widget mock |
| HTTP riêng trong UI harness | 3 | 0/0/0 | Owner isolation, Admin role, DISABLED login |
| PostgreSQL UI audit checks | 5 | 0/0/0 | UUID/owner/dates/price/periods/audit/no unrelated mutation |
| Cleanup checks | 24 | 0/0/0 | 8 DB task sở hữu; chạy lại vẫn đạt, không cộng hai lượt |

Không cộng tests với checks, không cộng focused vào full. Full này **không chọn** PtActivationPostgresTest/ActivationSchemaRehearsalTest, không gọi skipped0 là đã chạy chúng. PT unit/activation/mail tests còn nằm trong scoped full; không redo OTP PostgreSQL/SMTP/UI task đã đóng. Không quảng bá E2E toàn FitCenter. [Bảng fresh JUnit/test summary](M03_TEST_RESULTS.json).

Admin/Member `flutter analyze --no-fatal-infos` exit0,0error/0warning, còn **65/44 info** Material/style; không tuyên bố strict lint clean. `flutter test --reporter expanded`; cả hai JS `flutter build web --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:18083/api/v1` đạt. PT Dart không đổi, không rerun PT. Không bulk update dependency/SDK constraints.

## Backend/schema đã kiểm chứng

- ADMIN ACTIVE only, input missing/null/type/UUID/unknown/duplicate field/precision/range, price0, duration/date VN inclusive/leap/month/year/range; không User ACTIVE requirement cho recipient, không đổi User/hash/JWT.
- Any historical Membership status chặn initial. Plan ACTIVE, đổi giá ->409, snapshot giữ name/duration/price/dates sau thay đổi; cùng key/canonical payload qua ngày mới/giá mới trả snapshot cũ200, không audit thêm; khác key/receipt/payload conflict chuẩn.
- Cạnh tranh thật qua CyclicBarrier + khóa Member ngoài transaction; chờ pg_stat_activity xác nhận lock waits trước unlock. Cùng Member/different key, khác Member/same key, normalized duplicate receipt, actor bị khóa trong lúc chờ; tối đa một commit như contract. Clock quyết định lấy sau chờ.
- Fault injection trigger tại4 bước membership/payment/receipt/audit: rollback nguyên tử, retry cùng key sau khi gỡ fault tạo đúng1 bộ dữ liệu.
- V9 chạy trên2 DB trống mỗi lượt: empty và history seededV1–V6. Snapshot toàn bộ legacy rows trước/sau bằng nhau;6 payments bao gồm SUCCESS/REFUNDED/FAILED/CANCELLED/PENDING và NULL membership link. Không mất `period_start/period_end`.
- V7 chỉ được resolve để validate-only migration order: Flyway từ chối V7 đến muộn khi outOfOrder=false trước DDL; history và2period columns giữ nguyên. Không apply V7/V8, không sửa migration đã apply/clean/repair/history.

JDK **21.0.13+9**, PostgreSQL container **0ea4844f2515e49ebad21d8ffc5cd3c4f9561b02c41e6ad5425b2aef5de17c12**, volume **fitcenter_membership_20261123_data**, host **127.0.0.1:15440**, app-role không admin. Fresh full run nonce **d0b343106ce0**, DB fitcenter_membership_d0b343106ce0_(empty|history)_test, history **1,2,3,4,5,6,9**. Docker desktop-linux/context/containerID/label/volume/port/database/user/privileges xác minh trước Flyway. Không DB chung/production.

## UI thật và PostgreSQL

Chrome headless installed, viewport **1024×768**, browser timezone **America/Los_Angeles**, server Clock thật. Login/Home/navigation Admin gốc; form numbered Cards/theme giữ lại. ACTIVE/DISABLED Member và plan30ngày/giá0 được **JDBC seed trực tiếp**, không chạy MEMBER email activation. Chỉ Membership/payment/receipt success dưới đây được tạo bằng **Admin UI POST201 thật**.

- Membership UUID **639d8e58-f77c-4aba-bc15-20a021da13d5**, Member profile UUID **8cab0dd6-dd16-4d29-a233-d60d39980f64**.
- Payment UUID **e3dea5f8-ecbb-4955-badd-e3c97199d77f**, receipt activation UUID **dcba6dae-7fae-4128-881e-df5afc1427c7**.
- Server days **2026-11-23 → 2026-12-22**, ACTIVE, COUNTER SUCCESS **0.00 VND**,30 ngày; payment.period_start/end khớp.
- Admin reload/login→GET receipt đúng snapshot/UUID; Member fixture ACTIVE reload/login→M-04 cùng UUID/date/status. Member B không thấy row của A; Member không đọc Admin endpoint; DISABLED Member không login nhậnJWT.
- Member khác dùng chứng từ đã chuẩn hóa trùng ->409 ERR_RECEIPT_ALREADY_USED; UI hiển thị lỗi, không fake success; DB không thêm Membership/payment cho Member đó.
- DB snapshot loại đúng4 bộ UUID mới (membership/payment/receipt/audit) bằng snapshot trước: User/account/Booking/slot/policy/legacy payments không đổi. Một audit duy nhất.

[Structured UI/HTTP/DB results và exact source hashes tại lượt UI](M03_UI_DB_RESULTS.json); JSON không credential/header/token. [Final27 executable source/test/helper hashes](M03_SOURCE_HASHES.json); Java/Dart/tests không đổi sau lượt thành công. Chỉ bỏ blank EOF dư của hai PowerShell wrappers sau UI, đã kiểm nội dung rstrip CR/LF bằng nhau; cleanup helper mới được chạy riêng sau UI. Không lặp full832 chỉ vì tài liệu/whitespace.

Ảnh cùng viewport, dữ liệu tổng hợp, không email/password/token:

- [Admin tạo Membership từ server](m03-initial-activation/admin-created-receipt.png).
- [Admin reload đọc snapshot đã commit](m03-initial-activation/admin-reloaded-receipt.png).
- [Form chứng từ trùng](m03-initial-activation/admin-duplicate-conflict.png) (mã lỗi nằm phía trên vùng chụp, UI assertion/HTTP409 trong JSON xác minh).
- [Member M-04 cùng UUID](m03-initial-activation/member-m04-membership.png).
- [Member reload/login vẫn đọc được](m03-initial-activation/member-reloaded.png).

## Failures đã sửa và giới hạn

Các lượt thử trước **không gọi là pass**: snapshot test ban đầu tính cả plan riêng BeforeEach; fixture cleanup actor FK khi xóa Admin trước audit Member; đã sửa oracle và cleanup hai-pass/UUID ledger. Lượt focused cuối62 và full832 sau sửa đạt. Widget double-retry test gặp Flutter async-guard do assert trong HTTP callback; chuyển capture/assert ra ngoài và Admin89 cuối đạt. UI helper lỗi role menuitem/đợi semantics/scroll; một lượt đã201 nhưng không đọc được UUID SelectableText, bổ sung Semantics rồi cleanup đúng UUID trước fixture mới; lượt UI cuối24/3/5 gắn source cuối đạt. Không che failure bằng gửi POST mới chồng dữ liệu cũ.

Default M-03 false/503; profile membership-rehearsal riêng mới bật. PT activation vẫnfalse/default, V8 giữ nguyên. V9 test location chưa là canonical release. Cần Duy đồng bộ version/order với V7/V8 và backfill V7 giữ payment periods, nhận diện COUNTER initial có transaction. Không rollout production, không MEMBER account activation/renewal/gateway/refund/Face/Workout, không đổi Booking.

## Cleanup/Git review

Cleanup theo UUID manifest/registry của từng DB; failed-run namespace test được xác nhận trong DB task mới tạo, lưu registry trước delete. Snapshot rows ngoài registry giữ nguyên, chạy lại cleanup đạt;8DB còn schema/history, không DROP/TRUNCATE/volume delete. [Cleanup/stop/remote review](M03_CLEANUP_RESULTS.json). Own backend/web/container đã dừng, ports3000/3002/18083/15440 đóng, volume giữ; notification_service_app/food_booking_db không đổi.

Review M-03 không gồm4research untracked22/11 hoặc Face checkout gốc. Credentials/DPAPI/private manifests/raw Maven/Flutter logs/build/SDK/cache ở Temp/ignored, không stage. Fetch23/11 database ref558fb03 không đổi; remote0workflow/0run/0deployment/0webhook, không có CI pass để tuyên bố. Commit/push nhánh riêng sau review, không merge/force. Git commit cuối chứa evidence này; SHA local/remote báo ở bàn giao, không tự tham chiếu SHA của chính commit.
