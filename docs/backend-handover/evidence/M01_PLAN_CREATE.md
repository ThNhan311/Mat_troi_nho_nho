# M-01 — Admin tạo Membership Plan trên giao diện gốc

Ngày22/11/2026; branch **feature/admin-membership-plan-create**, HEAD/base **1b1e323ff8ac0f947b3145b6544bac81339931ba**. Thay đổi M-01 chưa stage/commit. Bốn tài liệu research untracked được đọc và giữ nguyên; không coi các proposal Membership/Payment còn mở là đã chốt. [Contract](../decisions/2026-11-22_M01_PLAN_CREATE.md), [quickstart](../15_BOOKING_WEB_QUICKSTART.md#m-01--admin-tạo-membership-plan-22112026), [hashes](M01_PLAN_CREATE_HASHES.json), [checks](M01_PLAN_CREATE_CHECKS.json).

Review cuối: **25 file M-01**, ngoài4 file khảo sát được giữ nguyên. Đối chiếu12 executable source/test/helper hashes và22 UI source hashes;89 local links tồn tại, credential fixture scan0match, index0file. Không stage/commit.

## Thay đổi và giới hạn

- Backend thêm request strict, service transaction và POST Admin create. Security /admin/** hiện hữu, không đổi SecurityConfig; service resolve/recheck ADMIN ACTIVE. Server UUID/ACTIVE,201 DTO cùng GET. Không field ngoài whitelist hoặc lặp; không coercion number-string/float→integer; giá BigDecimal trực tiếp, không double/rounding. V2 đủ, không migration/V7/unique name/dependency.
- Admin Home mở MembershipPage gốc. Giữ theme/layout/header/cards/icon/modal/FAB, bỏ mock và đơn vị tháng; list ACTIVE, thêm name/price/durationDays/description, hiện UUID. Sửa/xóa/trạng thái Chưa khả dụng, không local success. ApiClient/theme/Member/PT giữ nguyên byte. Session memory/epoch, modal theo navigator phiên, mounted guard, double-submit,201 matching DTO và unknown-outcome/no replay được giữ.
- Không account creation, activation, renewal/payment, plan update/status/delete hoặc Member Membership UI. Member GET đọc plan chỉ là HTTP read-back. Không thêm API đọc trùng, không quảng bá all-status list. D01 vẫn snapshot, không start marker, completion giữ R04.

## Kiểm thử thực chạy trên source cuối

| Loại | Passed | Failed | Errors | Skipped | Ghi chú |
|---|---:|---:|---:|---:|---|
| Backend focused HTTP harness |433|0|0|0|Có45 ca M-01 thật HTTP/PostgreSQL, toàn tập con của full |
| Backend full regression |720|0|0|0|668 baseline +45 HTTP M-01 +7 service unit; không cộng focused |
| Admin focused client/widget |27|0|0|0|Tập con của Admin full |
| Admin toàn bộ unit/client/widget cuối |63|0|0|0|36 tests cũ +27 M-01; chạy lại sau mounted guard cuối |
| Admin analyze |—|0 errors|0 warnings|—|39 infos deprecation/style; --no-fatal-infos, không bỏ errors/warnings |
| Admin release JavaScript Web build cuối |1|0|0|0|API_BASE_URL dart-define, no-web-resources-cdn |

Backend JDK21.0.13+9, default profile/JVM UTC; test guard xác minh containerID/label/volume/loopback15437, DB fitcenter_baseline_20261120_test, role app không đặc quyền và Flyway1–6 trước Spring/Flyway. DatabaseAlignmentTest là tên suite kiểm canonical, không chạy profile alignment. Không dùng668 lịch sử thay kết quả mới. Không chạy lại Backend sau khi chỉ sửa docs/runner UI.

HTTP M-01 kiểm201/DBACTIVE/GET list-detail cùngUUID/duration/price/description; Member GET; UUID server; role/account; required/missing/null; string/number/boolean/object/array; name blank/101 và Unicode100; TEXT12000; duration0/âm/int32 max/overflow/float/exponent; giá0/0.01/max/âm/quá scale/range/precision dài; hai tên trùng cóUUIDriêng; không nhận id/status/timestamps/owner; snapshot8 nhóm dữ liệu ngoài plan bất biến. Unit kiểm service actor recheck/không write khi mất quyền. Transaction rollback sau flush kiểm không còn row plan.

Admin tests kiểm DTO/error/correlation, whitelist/numeric input,0/int32/storage limits, wrongstatus/malformed hoặc mismatching201 là unknown, POST timeout chỉ1lần, loading/empty/error, reload, duplicate name, unsupported actions không write, double-submit, network/409 và logout khi pending GET/modal/POST bỏ response cũ. Tests role/login/refresh của client cũ vẫn chạy. Không đổi code chung Member/PT/static server, nên không chạy lại hai app; không ghi37/48 lịch sử là lượt này.

## UI/HTTP/DB — báo riêng, không cộng với JUnit/Flutter

Chrome headless thật, viewport1024×768, timezone America/Los_Angeles, Admin http://localhost:3002 và Backend loopback18081. Guarded runner CORS chỉ localhost3000/3001/3002, không wildcard/shared config.

Lượt cuối **16 UI checks passed,0 failed,0 skipped**: login Admin thật → Home gốc → Gói tập GET thật → modal tạo → POST201 đúng giá123456.78/duration37 → reload list → logout/login đọc cùng UUID → browser reload mất memory session → login/GET vẫn đúng UUID/giá/ngày → logout. Chỉ1POST tạo plan ở lượt cuối.

UUID cuối **17912087-c4a0-4598-b4f4-df71f8445e21**, ACTIVE, duration37, price123456.78, description tổng hợp. UUID lấy response UI, không suy từ tên. **3 HTTP checks riêng**: Member login200, GET detail khớp toàn DTO, GET list có đúng UUID/giá/ngày. **DB prepare2/audit3 checks**, cleanup4 rồi3 ở lần no-op; không cộng các pha có assertion lặp. DB audit đối chiếu cùng UUID/body/ACTIVE và snapshot ngoài plan không đổi.

| Ảnh1024×768 | Ý nghĩa |
|---|---|
| [List trước tạo](m01-plan-create/active-list-before-create.png) | Chỉ plan seed thật, không list mock |
| [Modal gốc](m01-plan-create/create-form.png) | Đơn vị ngày, giá decimal, description tùy chọn |
| [Sau201](m01-plan-create/created-plan.png) | UUID vừa tạo, success từ server, list reload |
| [Sau reload/login](m01-plan-create/persisted-plan.png) | Cùng UUID/giá/ngày đọc lại từ server |

Đã xem cả4ảnh; không credential/token/người thật/Face. Plan mới do UI tạo. ADMIN/2MEMBER/2PT và base plan/memberships do Seed trực tiếp, không tuyên bố tạo qua UI. Không cần policy hoặc booking/session seed cho M-01.

## Failure đã xử lý

- Lần gọi PowerShell script trực tiếp bị execution policy chặn; dùng PowerShell con -ExecutionPolicy Bypass theo quickstart, không đổi policy máy. Chưa có tests chạy ở attempt setup này.
- Build đầu thất bại vì cache Flutter thiếu dart2wasm_platform.dill/flutter.js.map. Kiểm SHA256 bundle chính thức3.50.1 khớp33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb, khôi phục đúng2file thiếu, không overwrite artifact có sẵn/hạSDK/upgrade dependencies. Build JavaScript cuối exit0; chưa nghiệm thu Wasm/native.
- Có5attempt UI harness lỗi trước lượt cuối: focus chưa ổn định gây field rỗng/không POST, và assertion exact chuỗi UUID của SelectableText không phù hợp DOM semantics. Một replacement helper chưa áp do encoding PowerShell→Node; đã kiểm nội dung file và sửa đúng dòng. Sửa wait/focus, xác nhận từng input trước POST, chờ modal đóng sau201; UUID/giá/ngày được kiểm bằng response, GET, DB và ảnh. Các attempt lỗi giữ riêng local; attempt2/3/5 nhận201 đã audit/cleanup đúngUUID, attempt1/4 không có plan mới. Không replay write chưa rõ hoặc dùng attempt lỗi làm pass.
- Một thao tác archive private evidence dừng ở path guard vì slash khác kiểu; không move trước khi kiểm đúng absolute parent, không mất evidence. Không source Java/Dart đổi do các lần sửa runner cuối; hashes UI cuối khớp22 file được runner chụp.

## Cleanup và trạng thái cuối

Helper DB kiểm registry UUID/body khớp, plan không thuộc baseline và không có membership/payment FK trước DELETE. Cleanup plan mới2lần, rồi BookingDemo cleanup fixture2lần, tất cả exactUUID; không truncate/broad delete/xóa theo tên. Sau cleanup9 bảng users/members/PT/plans/memberships/payments/bookings/slots/policy đều0, Flyway1–6 thành công. Manifest/credentials được giữ riêng local, seeded=false, không ghi đè credential khác.

Đã xác minh và dừng đúng Node PID29312, Java9476 và guarded wrapper28980 của task. Container test e4c5299f… đã dừng vì task tự start; volume fitcenter_baseline_20261120_data giữ nguyên. Port3002/18081/15437 không còn listen. Không dừng engine/tài nguyên khác.

M-01 vẫn unstaged/uncommitted, không push/merge. Bốn docs khảo sát/checkout gốc/Face giữ nguyên; không SDK/cache/build/raw log/manifest/credential trong phạm vi task. Không tuyên bố E2E toàn FitCenter, payment hoặc Member Membership UI đã hoàn thành.