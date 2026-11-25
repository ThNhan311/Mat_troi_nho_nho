# Khảo sát Frontend và lát cắt tích hợp booking

Khảo sát tiếp sau đóng D01, ngày làm việc 20/11/2026. Chỉ đọc source từ Git refs; không checkout, merge, sửa giao diện, cài SDK, chạy app hay khởi động DB. Báo cáo này là file mới chưa stage/commit, tách khỏi commit D01.

## D01 đã đóng local

- Nhánh vẫn `feature/backend-service-eligibility`; commit mới `089b5e27bda9cc4c543d5d239d3f51377b5e80af`, parent `63fe3945715888c7cbc9ad436c65d0e7f16273de`. Subject: `feat(backend): add PT service eligibility checks`.
- Review đủ 17 file: 5 production, 2 tests, 10 docs/OpenAPI; stage bằng danh sách chính xác, không `git add .`. Index rỗng trước stage; đối chiếu lại đúng 17 file trước commit. Không file Face, migration, secret hoặc dữ liệu thật trong diff đã review. Credential-pattern scan không phát hiện private key/JWT/GitHub/AWS token; đồng thời đọc thủ công code, tests và docs.
- Cả 7 SHA256 executable khớp [evidence D01](SERVICE_ELIGIBILITY.md); 21 Surefire XML hiện có tổng **668 passed, 0 failed, 0 errors, 0 skipped**, đúng lượt full cuối trong evidence. Đây là kết quả đã chạy trước bước đóng task, không phải chạy lại trong khảo sát. Không đổi executable nên không chạy full chỉ để commit. Focused là tập con, không cộng dồn.
- Đối chiếu API, OpenAPI và quyết định: chỉ snapshot hiện tại, no-store, không start marker, không đổi complete R04. Kiểm tra lại YAML/cấu trúc và 135 local references trên 20 paths bằng SnakeYAML/JDK21 thành công; không gọi đây là dedicated OpenAPI validator. Relative doc links và `git diff --check` đạt.
- Tài liệu D01 lưu trạng thái working tree lúc nghiệm thu làm checkpoint lịch sử; commit đóng task được ghi ở đây. Backend có API eligibility; chưa có Frontend tích hợp và chưa có luồng chặn dịch vụ end-to-end.
- Không push/merge/reset/stash; các file Face ngoài phạm vi giữ nguyên.

## Source Frontend thực tế

`git fetch origin` thành công, không thay đổi tip remote refs. Đã kiểm tra branches local/remote, cây ứng dụng trên mọi origin ref và worktree inventory. Chỉ có một worktree tại repository đang mở; không tạo worktree/đổi nhánh đồng đội. Checkout Backend hiện chỉ có `.gitkeep` trong [frontend](../../../frontend) và [mobile](../../../mobile), nhưng source ứng dụng nằm trên nhánh khác.

| Ref | Commit | Ý nghĩa |
|---|---|---|
| `frontend` = `origin/frontend` | `0307242a34ceb76a289f7ed1f43653e5a1862948` | Source đề xuất dùng cho khảo sát/tích hợp; chuyển 4 Flutter project vào frontend/ |
| local `main` | `e6457f1c311668923974f173fde8148ce32292af` | Thêm 4 project ở root; ahead origin/main 1, commit này cũng là ancestor của origin/frontend |
| `origin/main` | `5c8693bfaeb4c0e85f4c7bcb21c5fd487dad3516` | Chưa có các project Flutter trên ref này |
| Backend hiện tại | `089b5e27bda9cc4c543d5d239d3f51377b5e80af` | Backend R01–R04, policy write, D01 và harness |

Đối chiếu tree object từng project giữa local main và frontend: cả bốn bằng nhau, chỉ đổi đường dẫn; không có hai bản chức năng khác nhau cần tự hòa giải. Merge-base Backend/frontend là `5c8693b`; số commit riêng tương ứng 28/2. Không merge frontend vào Backend hoặc Backend vào frontend trong khảo sát. Các remote Backend/Face/schema còn lại không có app manifest tại các thư mục ứng dụng đã kiểm tra. Không tìm thấy AGENTS.md trên cây origin/frontend.

Các link source dưới đây ghim commit đã fetch; file chưa checkout nên không giả lập đường dẫn file local.

| Ứng dụng | Project trên ref frontend | Framework/source | Mức tích hợp thực tế |
|---|---|---|---|
| Member | [frontend/fitcenter_member](https://github.com/ThNhan311/Mat_troi_nho_nho/tree/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member) | Flutter Material, Dart; 26 file lib; package name `fitcenter` | Login form/demo; PT catalog, lịch, booking/history/cancel dùng memory/mock. Có HTTP client nhưng không được UI gọi |
| PT | [frontend/fitcenter_pt](https://github.com/ThNhan311/Mat_troi_nho_nho/tree/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_pt) | Flutter Material, Dart; 20 file lib; package `fitcenter_pt` | Login/demo; availability, sessions, cancel/complete dùng memory/mock. Client HTTP trùng byte với Member, chưa đúng API PT |
| Admin | [frontend/fitcenter_ad](https://github.com/ThNhan311/Mat_troi_nho_nho/tree/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_ad) | Flutter Material, Dart; 8 file lib; package `fitcenter_ad` | Vào AdminHomePage trực tiếp, không login/session; Booking Policy form chưa gọi server |

Có project kiosk thứ tư trên cùng ref; chỉ xác nhận tồn tại để không bỏ sót source. Không khảo sát hay sửa flow kiosk/Face trong task này.

Cả ba app có scaffolding Android/iOS/web/Windows/Linux/macOS. Pubspec yêu cầu Dart `^3.13.5`; lock ghi Dart `>=3.13.5 <4.0.0`, Flutter `>=3.18.0-18.0.pre.54`. Đây là constraints trong source, chưa xác minh SDK đáp ứng. Member/PT khai báo `http: ^1.6.0`, Admin chưa có HTTP dependency. README vẫn là template Flutter, không có quickstart/API environment riêng.

## Login, API client, token và môi trường chạy

- [Member login](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member/lib/screens/login_page.dart#L30) chỉ validate và hiện thông báo cần nối Backend. [Member main](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member/lib/main.dart#L55) và PT main mở Home bằng nút demo. Không có request login/refresh, auth state, lưu access/refresh token, interceptor hoặc logout thu hồi token. Không tìm thấy shared_preferences/secure storage trong ba app. Admin main mở Home trực tiếp.
- [BookingService Member](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member/lib/services/booking_service.dart) dùng `package:http`, nhận token từ caller; `http://10.0.2.2:8080/api/v1` hardcode. Có POST bookings, GET bookings/me, POST bookings/{id}/cancel. Cả ba chưa được screen import/call. GET thiếu hai query bắt buộc `from/to`, hiện sẽ bị Backend từ chối. Decode lỗi chỉ dùng top-level message, chưa phân loại error.code/correlationId hoặc refresh dữ liệu khi 409.
- [BookingService PT](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_pt/lib/services/booking_service.dart) có cùng Git blob `abc0cec3a48488a1a282d9b97cbc2214e058c3c8` với Member. Các đường `/bookings/me`, `/bookings/{id}/cancel`, POST `/bookings` là Member API, PT không được dùng; cần client PT đúng role.
- Backend [login response](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/dto/auth/LoginResponse.java) là object accessToken/refreshToken/role; login POST `/api/v1/auth/login` với email/password, refresh POST `/api/v1/auth/refresh` với refreshToken. Không trả profile ID. Chưa có contract rotation/revocation để UI tự giả định. Lát cắt dev tối thiểu có thể giữ session trong memory và yêu cầu đăng nhập lại khi reload; không hardcode token hoặc lưu vào Git/log. Nếu cần lưu bền, chốt cơ chế theo platform trước khi làm.
- Backend default port **8081**, không phải 8080; HTTP harness dùng random port và đóng server khi xong. Ví dụ OpenAPI port 18081 không có nghĩa server đang chạy ở đó. Cần chọn port riêng và xác minh lúc demo.
- [WebConfig](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/WebConfig.java) đã hỗ trợ GET/POST/PATCH/PUT/DELETE/OPTIONS, Bearer headers; default origin chỉ `http://localhost:3000`, có env `CORS_ALLOWED_ORIGINS`. Hai app web ở 3000/3001 cần allow đúng cả hai origins trên Backend demo riêng; không nới wildcard môi trường chung. Native Android cần kiểm tra host routing và HTTP cleartext/network policy thực tế; debug/profile manifest có INTERNET, main chưa có cấu hình network riêng.
- Chrome và Edge có binary local. `flutter`, `dart`, `adb`, `emulator` không tìm được trên PATH; không thấy SDK tại các vị trí Flutter thông dụng, LocalAppData Android SDK, Android env vars hoặc AVD người dùng. Thư mục C:/Android tồn tại nhưng không có entry đọc được qua enumeration. Không có adb/emulator process được tìm thấy. Chưa thể chạy flutter doctor/devices hay xác nhận thiết bị USB; không kết luận toàn máy chắc chắn không có SDK ở đường dẫn tùy chỉnh.
- Windows runner tồn tại nhưng chưa xác nhận toolchain C++ sẵn sàng; vswhere không trả instance có component VC.Tools.x86.x64. iOS/macOS cần máy phù hợp, không thể build trên Windows hiện tại. Web là mục tiêu demo nhỏ nhất sau khi có Flutter SDK đáp ứng và cấu hình base URL/CORS; Android emulator/thiết bị thật cần xác minh riêng.

Các lệnh dự kiến, **chưa chạy**, sau khi có checkout tích hợp riêng và SDK hợp lệ:

```powershell
flutter --version
flutter doctor -v
flutter devices
# Từ từng project được chọn:
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 3000  # Member
# Terminal/project PT riêng: flutter run -d chrome --web-port 3001
# Admin sau đó: flutter run -d chrome --web-port 3002
# Native: flutter run -d <device-id đã xác minh>
```

Các lệnh hiện chỉ mở source demo cho tới khi nối API; chưa có hỗ trợ API_BASE_URL qua dart-define trong code. Đề xuất thêm cấu hình theo target ở task tích hợp: web/desktop dùng host loopback và port Backend đã chọn; Android emulator dùng host alias phù hợp (client hiện dùng 10.0.2.2); thiết bị thật cần đường mạng tới host. Không mở port DB ra LAN hoặc đổi binding/firewall dùng chung trong khảo sát này.

## Màn hình → thao tác → API → phần còn thiếu

Backend API ở bảng đã có tại commit D01, được kiểm qua HTTP/PostgreSQL trong regression Backend. “Có thể nối” nghĩa là contract Backend có sẵn; chưa có hàng nào được xác minh chạy UI với Backend. Prefix tất cả API là `/api/v1`.

| Màn hình | Thao tác | API Backend | Mức sẵn sàng và thiếu gì |
|---|---|---|---|
| Member/PT Login; Admin entry | Đăng nhập, refresh, logout local | POST `/auth/login`, POST `/auth/refresh` | Backend sẵn; UI Member/PT form/demo, Admin thiếu login; cần session/role routing/Bearer/refresh có giới hạn, xóa session khi logout |
| Member TrainerListPage | Danh sách PT | GET `/trainers` | Có thể nối; thay static trainers bằng DTO UUID/fullName/bio/specialization/experienceSummary |
| Member TrainerDetailPage | Hồ sơ PT | GET `/trainers/{ptId}` | Có thể nối; hiện nhận chuỗi từ list mock, thiếu ID; rating/số buổi chưa có trong DTO, cần ẩn/đánh dấu chưa có thay vì bịa dữ liệu |
| Member SchedulePage | Xem slot của PT | GET `/trainers/{ptId}/slots?from&to` (alias `/availability`) | Có thể nối; thay PT-001/SLOT-... bằng UUID, bỏ lịch cố định tháng 10/2026 và slot tĩnh; quản lý selection và trạng thái tải/lỗi/rỗng |
| Member SchedulePage/HomePage | Đặt slot | POST `/bookings` `{ptId,slotId}` → 201 CONFIRMED | Client skeleton gần đúng input; screen đang Future.delayed rồi insert Map local, chưa gọi client. Chỉ xác nhận sau 201; lưu response ID/time; refresh slots + lịch |
| Member BookingHistoryPage/lịch | Lịch cá nhân | GET `/bookings/me?from&to&status` | Có thể nối; client thiếu from/to, UI dùng list memory và chuỗi ngày/giờ, chưa có booking UUID |
| Member BookingHistoryPage | Hủy lịch | POST `/bookings/{id}/cancel` → 200 booking | Client skeleton có; UI chỉ đổi status local. Cần dùng booking.id, lỗi policy/deadline/conflict, tải lại lịch và slot; không tự suy ra deadline cố định |
| PT AvailabilityPage | Xem availability | GET `/pt/slots?from&to&status` | Có thể nối; list demo date/start/end/booked boolean chưa có UUID/status enum và không gọi API |
| PT AvailabilityPage | Tạo slot 90 phút | POST `/pt/availability` `{startAt,endAt}` → 201 slot | Có thể nối; local validator đã có 90 phút/overlap nhưng server quyết định. Không gửi ptId; thay add local bằng response và refresh |
| PT AvailabilityPage | Sửa slot | PATCH `/pt/availability/{slotId}` → 200 slot | Có thể nối; lưu ID trả về, có thể là ID thay thế; reload list, không giữ ID cũ làm slot đang chọn |
| PT AvailabilityPage | Loại slot khỏi availability | DELETE `/pt/availability/{slotId}` → 204 | Có thể nối; Backend DISABLED giữ lịch sử, UI không giả định physical delete; xử lý BOOKED/409 rồi reload |
| PT HomePage/ConfirmedSessionsPage | Lịch/session sở hữu | GET `/pt/bookings?from&to&status` | Có thể nối; đang BK001/date/start/end/memberName mock. Client hiện gọi Member URL sai role; DTO Backend chỉ có memberId, không memberName |
| PT SessionDetailPage | Hủy có lý do | POST `/pt/bookings/{id}/cancel` `{reason}` | Form reason có; hiện set CANCELLED/cancellationReason local. Cần lưu cancelReason/cancelledBy/cancelledAt từ DTO, cửa sổ now<start, 409 có mã ổn định |
| PT SessionDetailPage | Kiểm tra trước buổi tập | GET `/pt/bookings/{id}/service-eligibility` | Backend D01 sẵn; UI chưa có thao tác/result model. Đọc eligible/reasonCodes/checkedAt, không cache hay tạo start marker |
| PT SessionDetailPage | Hoàn tất | POST `/pt/bookings/{id}/complete` → 200 booking | Nút/local check end có; hiện chỉ set COMPLETED local. Cần server Clock/response và complete theo R04, không gate bằng GET eligibility |
| Admin BookingPolicyPage | Đọc policy hiệu lực | GET `/admin/booking-policy` | Có thể nối sau login Admin; hiện controllers mặc định 14/2/4/5, không GET. Xử lý 404 cấu hình chưa tồn tại, không giả tạo fallback |
| Admin BookingPolicyPage | Thiết lập/cập nhật | PUT `/admin/booking-policy` bốn số nguyên | Form bốn fields đã có minima cơ bản; chưa gửi request. Bỏ client scheduling/effective date picker và quá-khứ check; effectiveFrom là kết quả server, không input |

Source screens: [Member Home](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member/lib/screens/home_page.dart#L142), [Member Schedule](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member/lib/screens/schedule_page.dart#L37), [Member history](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_member/lib/screens/booking_history_page.dart#L82), [PT availability](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_pt/lib/screens/availability_page.dart#L11), [PT sessions](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_pt/lib/screens/confirmed_sessions_page.dart#L18), [PT detail](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_pt/lib/screens/session_detail_page.dart#L244), [Admin policy](https://github.com/ThNhan311/Mat_troi_nho_nho/blob/0307242a34ceb76a289f7ed1f43653e5a1862948/frontend/fitcenter_ad/lib/screens/booking_policy_page.dart#L12). Backend contracts: [API guide](../05_API_DOCUMENTATION.md), [OpenAPI](../api/openapi.yaml), [D01](../decisions/2026-11-20_SERVICE_ELIGIBILITY.md).

## Các điểm contract cần thống nhất khi nối

1. `users.id` khác `members.id`/`personal_trainers.id`. Login không cung cấp profile ID; không lấy email/JWT subject/user ID rồi gán ptId/memberId. Trainer DTO.id là PT profile UUID; slot DTO.id là slot UUID; booking DTO.id là booking UUID. Member/PT ownership do principal phía Backend quyết định; các write chỉ gửi input đúng contract, không client owner IDs. Không cần thêm endpoint identity chỉ để thực hiện lát cắt này.
2. Auto-confirm sau 201, không PT approval/PENDING/REJECTED. UI hiện dùng CONFIRMED/CANCELLED/COMPLETED là phù hợp; thay mô phỏng thành kết quả server. Không thêm bước duyệt khi tích hợp.
3. Thành công là DTO hoặc array trực tiếp, không `{data:...}`. Error có `success:false`, `error:{code,message,details,correlationId}`, timestamp/status/message và X-Correlation-Id; dùng error.code để xử lý nghiệp vụ, tránh chỉ bắt Exception chung. UUID là string, camelCase `id/memberId/ptId/slotId/startAt/endAt/cancelReason`, khác map display hiện tại và `cancellationReason` local của PT.
4. GET lịch/slots bắt buộc from/to ISO offset, range theo start trong `[from,to)`, status optional theo enum. Encode dấu `+` nếu dùng +07:00. Giữ Instant/UTC cho dữ liệu và request có offset; hiển thị/ngày nghiệp vụ Asia/Ho_Chi_Minh, không mặc định timezone máy luôn Việt Nam. Membership DATE/expiry inclusive đã do Backend xử lý; không chuyển DATE thành UTC midnight trong UI.
5. PATCH slot có lịch sử và đổi giờ có thể trả UUID mới; thay toàn DTO/selection bằng response, refresh danh sách. DELETE thành công là 204 không JSON, DISABLED phía DB; giữ booking history. Không giả định cùng ID hoặc xóa vật lý.
6. 409 cần tải lại slot/booking/list liên quan và bỏ selection cũ nếu không còn hợp lệ; không retry write mù. Request hủy cũ phải giữ booking.id cũ, không tìm booking mới từ slot.id rồi hủy nhầm sau rebook. Chỉ cập nhật trạng thái UI từ response thành công.
7. Eligibility false vẫn HTTP200. Đọc eligible và sáu reasonCodes, hiển thị checkedAt UTC theo giờ Việt Nam; no-store cả phía UI/service-worker. Kết quả là snapshot, có thể cũ ngay sau response; gọi mới khi cần, không xem đó là quyền sử dụng lâu dài. Không marker startedAt, không IN_PROGRESS, complete không bắt buộc GET trước.
8. Member cancel dùng deadline của policy hiệu lực lúc request, kể cả booking cũ sau Admin PUT; UI không hardcode 4 giờ hoặc chặn dựa vào cấu hình cũ. PT cancel chỉ trước startAt, reason bắt buộc; đúng start hoặc sau trả ERR_PT_CANCELLATION_WINDOW_CLOSED. Complete chỉ CONFIRMED, now>=end; server quyết định khi đồng hồ client lệch.
9. Chưa có policy-read contract cho Member/PT. Nếu UI muốn hiển thị chính xác advance/notice/deadline/max-future trước thao tác, đây là khoảng trống API cần chốt riêng. Không gọi Admin API bằng token Member/PT, không phân phối Admin token, không coi fixture14/2/4/5 là policy sản phẩm. Lát cắt đầu có thể không hiển thị các giới hạn động và hiển thị lỗi server đúng mã.
10. PT bookings trả memberId chứ không memberName; chưa có contract PT đọc tên Member từ các booking này. Lát cắt đầu hiển thị định danh rút gọn/nhãn kiểm thử rõ ràng, không gọi API Member bằng PT hoặc lấy catalog tài khoản Admin. Nếu cần tên cho sản phẩm, chốt DTO/read contract tối thiểu và quyền riêng tư ở task sau. Rating/số session trên hồ sơ PT cũng chưa có Backend fields.
11. Admin UI cho chọn ngày áp dụng bất kỳ và từ chối thời điểm quá khứ, trái D05 immediate-only. Bỏ input scheduling; GET/PUT trả effectiveFrom do server đặt. Bốn minima là 1/0/0/1; không tự áp quan hệ giữa fields hay max tùy ý ngoài contract int32. Không tự hủy booking cũ khi giảm maxFutureBookings.

## Đề xuất lát cắt tích hợp đầu tiên

Source/base đã xác định: frontend snapshot `0307242` và Backend `089b5e2`. Ở task triển khai tiếp theo, tạo nhánh/worktree tích hợp riêng từ Backend này và đưa đúng thư mục Member/PT từ snapshot Frontend đã ghim vào đó sau khi kiểm tra collision; không checkout/ghi đè nhánh đồng đội hay tự merge toàn cây Backend cũ từ nhánh frontend. Chưa thực hiện thao tác này trong khảo sát. Admin UI để sau; dùng ADMIN qua API riêng để cấu hình fixture demo ban đầu.

1. Có Flutter SDK đáp ứng manifests, xác minh `doctor/devices`; chọn web hai origin cố định làm target đầu. Thêm cấu hình base URL và auth session cho Member/PT; POST login, Bearer, refresh tối đa có kiểm soát khi hết access token, lỗi refresh yêu cầu đăng nhập lại. Không cần token/profile hardcode hoặc endpoint mới.
2. PT login → GET own slots theo range → POST một slot tương lai đúng 90 phút. Refresh slots, giữ UUID thực. Chưa cần PATCH/DELETE để chứng minh lát cắt nhỏ nhất.
3. Member login → GET trainers → chọn PT bằng profile UUID → GET available slots → POST booking bằng đúng ptId/slotId. Sau 201 hiển thị CONFIRMED/ID/time từ response.
4. Reload GET Member bookings và GET PT bookings cho cùng range; cả hai thấy cùng booking UUID/time, slot biến mất khỏi Member available và PT thấy BOOKED. Dùng refresh thủ công/on-resume trước, chưa cần WebSocket/polling/dependency mới. Đăng nhập Member B/PT B xác minh ownership không rò dữ liệu.
5. Sau khi lát cắt trên đạt UI/HTTP/DB đối chiếu, thêm Member/PT cancel, availability edit/delete, D01 eligibility, complete; cuối cùng Admin login và GET/PUT policy form immediate. Giữ complete độc lập với start marker; không phát triển Membership/Payment/Face trong lát cắt.

Thay đổi tối thiểu nằm ở config/session/client/model và state của các screen trên, không cần migration hay Backend endpoint mới cho đường happy path đầu. Các khoảng trống policy-public-read/memberName/rating không chặn demo ID-based, nhưng phải chốt trước khi UI hứa cung cấp những thông tin đó.

## Kế hoạch demo bằng fixture riêng

Chưa tạo fixture demo, chưa khởi động server/DB và chưa chạy UI demo. Container test riêng hiện đọc lại là **exited**, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, label fitcenter.task=baseline-20261120, volume fitcenter_baseline_20261120_data tại /var/lib/postgresql/data, port127.0.0.1:15437→5432. Không thay đổi resource. Database/role phải được xác minh lại khi thực sự chạy, không coi docker inspect là đã xác minh datasource bên trong.

- Dùng môi trường demo/test riêng đã xác minh theo [runner guide](../14_HTTP_BASELINE.md): JDK21, đúng container/volume/port/database/role và history V1–V6 trước Spring/Flyway. Không alignment, onboarding BLOCKED, V7, clean/repair hoặc tài nguyên dùng chung. Có thể dành môi trường test hiện tại trong cửa sổ demo độc lập với regression; chưa giữ chỗ hay thay đổi tài nguyên ở task này.
- [HttpBaselineFixture](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineFixture.java) là AutoCloseable và server test RANDOM_PORT đóng sau suite; dữ liệu/token cũ không dùng làm tài khoản demo bền. Chưa có lệnh persistent demo seed trong scripts hiện tại. Không chạy xong tests rồi giả định có thể login bằng fixture.
- Task demo cần chế độ seed/cleanup riêng có manifest UUID trong vùng local ngoài Git, tạo ADMIN + 2 MEMBER/profile + 2 PT/profile, plan/memberships tổng hợp ACTIVE bao phủ session theo ngày Việt Nam. Dùng email example.invalid, mật khẩu ngẫu nhiên/cấp qua prompt, BCrypt từ PasswordEncoder thực tế; giao credentials trong kênh local riêng, không Git/báo cáo/log/token hardcode. Seed chỉ chạm UUID đã đăng ký; cleanup theo đúng manifest/FK, không truncate/xóa theo khoảng hay reset DB.
- Dùng Admin login + PUT policy rõ ràng để thiết lập 14/2/4/5 trong DB demo ban đầu; GET policy xác nhận. Không mặc định hóa GET hoặc logic nghiệp vụ. Lát cắt đầu chọn slot tương lai an toàn, ví dụ ngày hôm sau, >notice và <14×24h, 90 phút, không overlap, số booking dưới5. Seed ban đầu không cần booking để quan sát write từ UI.
- Khởi động Backend thường bằng JDK21 trên port local dành riêng đã kiểm tra trống, datasource chỉ DB test riêng, credentials/JWT qua process env/secure prompt. Cho phép đúng origins web đã chọn bằng CORS_ALLOWED_ORIGINS trên process demo. Cấu hình client tới URL thật của process này, không random port test/8080 cũ; không đổi Java mặc định máy.
- Mở hai app/tài khoản riêng, chạy chuỗi PT tạo→Member đặt→cả hai lịch. Đối chiếu status/payload và DB booking CONFIRMED/slot BOOKED, owner IDs/time và available list; không chỉ HTTP200. Tranh slot trả409 thì reload. Refresh app xác nhận dữ liệu lấy lại từ API chứ không list memory. Member B/PT B không thấy booking của A.
- Cancel/eligibility/complete demo sau cần các session tổng hợp theo thời gian thật phù hợp, không đổi Clock production bằng endpoint test. D01 chỉ true trong cửa sổ90phút, complete chỉ sau end; không ép chuyển state ngoài contract để làm demo. Thiết kế các scenario này riêng khi nối lifecycle.
- Kết thúc: logout/xóa session local, cleanup đúng UUID kể cả booking/slot mới tạo đã đăng ký, dừng đúng process Backend/DB tự khởi động cho demo, giữ volume. Không cleanup dữ liệu ngoài fixture hay tài nguyên đồng đội.

## Kiểm chứng, blocker và giới hạn

Đã thực hiện: Git status/refs/worktrees/fetch; đối chiếu 17 file/7 hashes/evidence668; review API/OpenAPI/decision; YAML/local-ref/link/whitespace/credential-pattern checks; đọc source Frontend bằng git show/grep/ls-tree và so tree objects; kiểm tra command/SDK candidates/browsers/device processes; đọc cấu hình CORS/port/DTO/controllers/fixture; Docker inspect an toàn không in env/secrets. Không sửa source Frontend hoặc executable Backend sau commit.

Tests mới trong bước khảo sát: **không chạy**. Backend full cuối được xác minh lại evidence là668/0/0/0; không gọi đó là lượt vừa chạy. Frontend analyze/test/build/device/demo đều **chưa chạy do chưa có SDK/checkout tích hợp**, không có số passed/failed/skipped để báo. Không cộng chúng vào JUnit skipped=0 hoặc gọi đây là E2E.

Đọc tĩnh đã phát hiện test cần sửa trước CI Frontend: Admin widget test gọi MyApp nhưng main chỉ khai báo FitCenterAdminApp; Member test đòi Trang chủ ngay sau startup trong khi main mở Login; PT test chỉ kiểm1+1. Đây là phát hiện source, chưa phải kết quả flutter test. Không sửa ở task khảo sát.

Blocker trước chạy: xác minh/cấp đường dẫn Flutter SDK và toolchain/target; chuẩn bị checkout tích hợp riêng với hai commit nguồn trên; client config/auth và mapping UUID/query range; persistent fixture demo/lifecycle cleanup riêng. Blocker contract cho UI đầy đủ: public policy information cho Member/PT và tên Member trong PT session (cùng rating/số buổi PT) chưa có; không tự mở quyền hoặc thêm API trong khảo sát. Không có schema blocker cho lát cắt nhỏ nhất đã đề xuất.

Kết thúc vẫn trên nhánh D01, chỉ báo cáo khảo sát mới chưa stage cùng các file Face ngoài phạm vi. Không push/merge, không áp V7/sửa migrations hoặc làm Membership/Payment/Face; không thay đổi tài nguyên dùng chung.
