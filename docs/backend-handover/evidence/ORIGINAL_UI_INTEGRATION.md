# Booking Web — tích hợp vào giao diện gốc

Ngày 22/11/2026. Đây là kiểm chứng lát cắt Booking Member/PT, không phải E2E toàn FitCenter.

## Nguồn và checkpoint

- Backend base: `089b5e27bda9cc4c543d5d239d3f51377b5e80af`.
- Frontend gốc: `0307242a34ceb76a289f7ed1f43653e5a1862948`; chỉ hai app đã import ở lát cắt trước.
- Đóng lifecycle: `cb749ae20ad97ab923577bd36d4ba1703375deda` (`feat(web): integrate booking lifecycle for Member and PT`). Đã review đủ 39 file và 19 hashes, đối chiếu evidence Member30/PT41, HTTP41/DB13; không chạy lại chỉ để commit.
- Task hiện tại: `feature/frontend-original-ui-integration`, HEAD `cb749ae`; giữ working tree chưa stage/commit. Không push/merge.
- Checkout gốc/Face/survey ngoài task giữ nguyên. Không thay production Backend, migration, POM, dependency hoặc API client đã kiểm chứng.

## Màn hình gốc → API

| Màn hình | Thao tác đã nối | Contract |
|---|---|---|
| Member Login | Form gốc → auth login/refresh | Chỉ MEMBER; session memory; reload đăng nhập lại |
| Member Home/navigation | Tổng quan từ bookings; tab gốc | Không tên/count mẫu; dữ liệu trong khoảng xem |
| Trainer list/detail | GET trainers, GET trainers/{profile UUID} | Không bịa rating/số buổi; mục chưa có dữ liệu ghi rõ |
| Member Schedule | Calendar ngày Việt Nam → available slots → POST bookings | UUID PT/slot thật; 201/CONFIRMED; auto-confirm |
| Booking history | GET bookings/me, xác nhận POST booking.id/cancel | Server quyết định deadline; 409/thiếu policy không đổi state giả |
| PT Login/Home/navigation | Auth PT; tổng quan lịch hôm nay | Member định danh rút gọn, không tên giả |
| PT Availability | GET slots; POST/PATCH/DELETE availability | 90 phút; PATCH dùng ID response mới; DELETE204 không decode JSON |
| Confirmed sessions | GET pt/bookings + bộ lọc gốc | Có trạng thái cuối từ server; không PT approval |
| Session detail | PT cancel reason, eligibility, complete | Snapshot/no start marker; complete độc lập lần GET trước |
| Profile/theme/logout | Layout gốc, theme và logout | Contact/profile edit/notifications chưa có API → Chưa khả dụng |
| Membership/Payment/Workout/Face | Không tích hợp | Luồng chính không mở mock như dữ liệu vận hành |

Hai [entry points Member](../../../frontend/fitcenter_member/lib/main.dart) và [PT](../../../frontend/fitcenter_pt/lib/main.dart) mở Home/navigation gốc sau login. Các dashboard trước vẫn giữ trong source để bảo toàn regression, không được dùng làm entry chính. Hai [widget regression Member](../../../frontend/fitcenter_member/test/widget_test.dart) và [PT](../../../frontend/fitcenter_pt/test/widget_test.dart) dùng harness riêng cho dashboard cũ; tests navigation mới kiểm tra entry thực tế.

Giữ theme, màu, typography, icon, card, calendar và navigation từ nguồn gốc. Chỉ thêm refresh/loading/error/empty, metadata server, xác nhận và kết quả eligibility. Wrapper Material trong Profile Member sửa assertion ListTile của SDK mà không đổi kiểu dáng. Các dialog/date/time picker nằm trong Navigator theo phiên: logout loại cả route, modal và draft. Không hiện nội dung kỹ thuật session memory trong UI.

## Kiểm chứng và phạm vi

| Nhóm cuối | Passed | Failed/errors | Skipped |
|---|---:|---:|---:|
| Member Flutter tests |37|0|0|
| PT Flutter tests |48|0|0|
| Member/PT analyze --no-fatal-infos |exit0 cả hai|0 error/warning|không áp dụng|
| Member/PT release Web JavaScript build |thành công cả hai|0|không áp dụng|
| HTTP baseline thật |26 checks /19 requests|0|0|
| HTTP lifecycle thật |41 checks /20 requests|0|0|
| DB lifecycle |13 checks|0|0|

37/48 gồm toàn bộ coverage client/session/lifecycle cũ và 7 tests mới mỗi app cho navigation/state/modal theo phiên. Focused là tập con, không cộng vào full. HTTP checks/DB checks/UI scenarios tách khỏi Flutter tests; 668 Backend là lịch sử, không phải lần chạy này. Production Backend không đổi nên không chạy lại full Backend. Không kiểm chứng native/Wasm.

[Runner UI Chrome](../../../frontend/verify-original-ui.mjs) dùng Playwright trong thư mục công cụ riêng, không thêm dependency project. Browser headless Chrome thật, viewport1024×768, timezone Los Angeles; app vẫn hiển thị giờ Việt Nam. Gọi UI bằng form/button/calendar/date/time picker, không gọi API write thay UI. Auth credential chỉ đọc từ manifest local, token không ghi/log. Fault injection route.abort/401 kiểm tra UI client, không gọi đó là authorization test Backend; role/ownership thật nằm ở HTTP probes.

Runner lưu source hashes và write intent **trước** thao tác, response status/UUID sau thao tác; từ chối pha/write đã thử hoặc source đổi giữa lượt. Nếu lỗi/timeout: dừng, Audit/Capture bằng manifest và đối chiếu DB, không tự chạy lại write. Pha member-read-only chỉ đọc booking UUID đã biết. Dùng manifest/result mới sau cleanup để chạy lại một lượt đầy đủ.

## Ảnh trước/sau

Ảnh `before-*` được chụp trước khi sửa production UI từ preview local export đúng screen source0307242; dữ liệu prototype chỉ làm mốc thiết kế. Preview route giúp mở từng screen độc lập; Schedule/history/detail có thể không chứa navigation của Home. Không coi preview là kiểm chứng API. Ảnh `after-*` và `ui-*` lấy từ app nối Backend thật. Cả 11 cặp before/after đều1024×768; theme source không đổi so với0307242.

| Screen | Trước | Sau |
|---|---|---|
| Member Login |[ảnh](original-ui/before-member-login.png)|[ảnh](original-ui/after-member-login.png)|
| Member Home |[ảnh](original-ui/before-member-home.png)|[ảnh](original-ui/after-member-home.png)|
| Trainer list |[ảnh](original-ui/before-member-trainers.png)|[ảnh](original-ui/after-member-trainers.png)|
| Trainer detail |[ảnh](original-ui/before-member-trainer-detail.png)|[ảnh](original-ui/after-member-trainer-detail.png)|
| Schedule |[ảnh](original-ui/before-member-schedule.png)|[ảnh](original-ui/after-member-schedule.png)|
| History |[ảnh](original-ui/before-member-history.png)|[ảnh](original-ui/after-member-history.png)|
| PT Login |[ảnh](original-ui/before-pt-login.png)|[ảnh](original-ui/after-pt-login.png)|
| PT Home |[ảnh](original-ui/before-pt-home.png)|[ảnh](original-ui/after-pt-home.png)|
| Availability |[ảnh](original-ui/before-pt-availability.png)|[ảnh](original-ui/after-pt-availability.png)|
| Sessions |[ảnh](original-ui/before-pt-sessions.png)|[ảnh](original-ui/after-pt-sessions.png)|
| Session detail |[ảnh](original-ui/before-pt-session-detail.png)|[ảnh](original-ui/after-pt-session-detail.png)|

## Lỗi phát hiện và đã xử lý

- Assertion ListTile/DecoratedBox của screen gốc trên SDK mới: thêm Material trong card giữ thiết kế.
- `const` với trạng thái session động và helper không còn dùng: sửa trước build.
- Feedback đặt lịch ở đầu ListView có thể ngoài viewport: đưa Schedule về đầu sau response.
- Root dialog có thể sống lâu hơn session: chuyển modal vào Navigator theo account và thêm tests logout lúc modal đang mở.
- Runner đọc innerText thiếu text được Flutter gộp trong aria-label, geometry card và selector eligibility: sửa runner, kiểm tra trace trước mọi lượt tiếp; không replay POST đã thành công. Các lượt dở không được tính là đạt.
- Browser tích hợp bị lệch semantic/canvas khi cuộn; chuyển kiểm chứng cuối sang Chrome riêng. Một snapshot tool trước đó đã lộ credential **tổng hợp**; đã rotate toàn bộ fixture password ngay, xóa khỏi form và không đưa vào ảnh/tài liệu/Git. Cleanup cuối xóa các actor fixture.
- Auto-review đã từ chối lệnh có khả năng replay booking. Đã dùng pha chỉ đọc đối chiếu booking có sẵn, thêm guard/intent; không cần dùng lại lệnh cũ sau khi được phê duyệt.

## Giới hạn

D01 có Backend và PT UI kiểm tra điều kiện tại thời điểm server checkedAt; không cache, không lưu bắt đầu, không bảo đảm điều kiện còn đúng sau response. Completion giữ R04, không ép GET trước đó. Chưa có luồng service-start ghi nhận/chặn giao dịch nguyên tử toàn hệ thống.

Không có contract tự sửa profile Member/PT, thông báo, rating/số buổi hoặc cung cấp policy cho Member/PT. Không gọi API Admin bằng role khác, không hardcode deadline4h. Calendar/lịch giới hạn khoảng xem; from/to gửi qua URI builder, ISO UTC/offset. Lịch PT tạm dùng UUID Member rút gọn. Client write timeout không replay; cần tải lại đối chiếu trước thao tác mới.

Xem [quickstart](../15_BOOKING_WEB_QUICKSTART.md), [hashes/provenance](ORIGINAL_UI_SOURCE_HASHES.json) và [kết quả UI/DB cuối](ORIGINAL_UI_RESULTS.json) cho lượt nghiệm thu cụ thể và cleanup.
## Lượt cuối và cleanup

Lượt Chrome cuối chạy từ03:17:51 đến03:19:47 UTC22/11/2026, sau sửa modal theo phiên và build lại cả hai app. Bảy pha đều đạt: pt-create4 assertions, member-book7, member-cancel-rebook8, pt-lifecycle-final12, pt-availability5, owners2, ui-error-feedback10. Không cộng các assertions có login/read trùng nhau thành số tests. 74 source hashes được giữ cố định qua toàn bộ lượt và kiểm lại sau cùng; 28 executable source/test/helper thuộc diff task có hashes riêng.

Booking tạo qua UI: `2b5b3eda-1c74-404f-91db-05cb3518d03e`, slot `60f6bc2c-bb99-4cd8-88a8-e78f31c5954b`, session24/11/2026 07:00–08:30Z (14:00–15:30 Việt Nam). Member/PT đọc cùng UUID/time; DB CONFIRMED/BOOKED, absent khỏi available. Member B rebook: `5dcbfa52-1887-421d-be92-ca8801e4fcc7`; PATCH trả slot thay thế `d83c117f-113a-4dd9-af43-a2a1c0258876`, lịch sử giữ ID/time cũ.

UI thật đã xác minh: Member hủy/Member B đặt lại; PT hủy có lý do; PATCH replacement/DELETE204; eligibility true/false; complete buổi seed đã kết thúc; Member B/PT B không thấy lịch A; reload/login vẫn đọc booking server; 409 deadline thật giữ state. Network/401 được fault-inject trong browser, không fake success/replay. Role/owner/disabled-slot rejection được kiểm bằng HTTP Backend thật.

HTTP26/41 và DB13 đã chạy lại cho đúng UUID fixture cuối sau khi review xác nhận lifecycle probe không tạo rebook/replacement: nó đọc trước rồi gửi negative requests dự kiến409/403/404. Auto-review lần đầu chặn do nghi write lặp; sau đối chiếu source và DB, hai probe được chạy thành công. Không dùng evidence lượt trước cho fixture cuối.

Cleanup đăng ký và xóa chính xác8slot/7booking thuộc manifest, actor/profile/plan/membership/policy tổng hợp. Tám bảng vềbaseline0; history `1,2,3,4,5,6|true`. Node/Java do task chạy đã dừng; guard runner tự thoát sau Java stop. Đã kiểm tra lại process không còn, port3000/3001/18081/15437 đóng, container test stopped; volume vẫn tồn tại. Không dừng container/process khác. Manifest/credential/SDK/cache/build/log nằm local ngoài Git hoặc ignored. Analyzer cuối còn42 Member/45 PT infos (deprecation/style), không error/warning.

Toàn bộ ảnh đã kiểm cùng viewport và review trực quan; không credential. Báo cáo này và hai JSON là evidence công khai, không kèm log riêng. Task giữ chưa stage/commit; Backend/migrations/Face và tài nguyên ngoài task không đổi.
Phạm vi diff cuối gồm72file:24tracked sửa và48file mới (38ảnh,6Dart source/tests,1UI runner,3tài liệu/JSON). Có28executable source/test/helper trong task; các file còn lại là docs/evidence. So với305file Frontend ghim:280file giữ nguyên nội dung,25file đã thay đổi qua các lát cắt tích hợp,0file mất. So sánh chuẩn hóa Git CRLF/LF được ghi trong provenance JSON; hai theme không đổi. Index cuối rỗng, không stage thay đổi task này.