# Admin Booking Policy — giao diện gốc

Nghiệm thu ngày 22/11/2026. Task trước đã đóng bằng commit local **425a0a86b498f88d96d3e49cde3aa9a76dd20ab7** (`feat(web): restore original Member and PT booking screens`). Đã review đúng72 file,28 executable/test/helper SHA256, provenance và evidence Member37/PT48; không chạy lại chỉ để commit. Index sạch sau commit; không push/merge.

Task Admin nằm trên **feature/frontend-admin-booking-policy**, HEAD425a0a8, thay đổi mới chưa stage/commit. Backend base089b5e27bda9cc4c543d5d239d3f51377b5e80af. Sau `git fetch origin frontend`, origin/frontend vẫn **0307242a34ceb76a289f7ed1f43653e5a1862948**; diff Admin với nguồn ghim bằng0 trước import. Chỉ git archive frontend/fitcenter_ad sau khi kiểm tra không collision; không merge nhánh/Backend/database cũ. Không AGENTS.md áp dụng trong cây/ancestors đã kiểm tra.

Phạm vi working tree:163 file gồm142 file Admin (137 file nguồn:130 nguyên bản,6 sửa,1 test mẫu được thay bằng6 file mới),13 ảnh và8 helper/tài liệu liên quan.18 executable source/test/helper hashes khớp evidence; index0 file.

## Source và giao diện

[Provenance, file sửa/thêm/xóa và SHA256](ADMIN_BOOKING_POLICY_HASHES.json) phân biệt source import nguyên bản với phần tích hợp. Main/Home/BookingPolicyPage giữ tên, theme, grid/card, typography, icon và navigation gốc. Theme và các màn hình module khác giữ nguyên byte source. Login mới tái sử dụng form Member theo theme Admin; không có Login trong nguồn Admin ban đầu. ApiClient và helper giờ Việt Nam được copy nguyên từ client đã kiểm chứng; không sửa Dart Member/PT. Test mẫu MyApp không tồn tại được thay bằng hai suite thực tế.

| Màn hình gốc | Tích hợp |
|---|---|
| Entry mở thẳng Home | Login ADMIN thật → Home gốc; role khác bị từ chối |
| Home grid/menu | Giữ bố cục; số liệu chưa nối API là “— / Chưa khả dụng”; module ngoài policy không mở mock vận hành |
| BookingPolicyPage | GET/PUT thật, bốn trường gốc; loading/error/missing/reconciliation |
| Chọn ngày hiệu lực | Bỏ scheduling; chỉ đọc effectiveFrom do server quyết định, UTC+07:00 |

Ảnh cùng viewport1024×768, Chrome thật với timezone máy giả lập America/Los_Angeles:

| Trước | Sau |
|---|---|
| [Home nguồn](admin-policy/before-admin-home.png) | [Home tích hợp](admin-policy/after-admin-home.png) |
| [Policy nguồn](admin-policy/before-admin-policy.png) | [Policy cuối đọc server](admin-policy/after-admin-policy-final.png) |
| Không có Login | [Login mới](admin-policy/after-admin-login.png) |

[GET404](admin-policy/after-admin-policy-empty.png), [policy vừa tạo](admin-policy/after-admin-policy.png), [network/reconcile](admin-policy/admin-policy-network.png), [logout](admin-policy/admin-logout.png). Ảnh nguồn là prototype tham chiếu, không phải evidence lưu Backend. Tất cả ảnh được review: không credential/token, dữ liệu người thật hoặc Face.

## Contract và session

- API_BASE_URL qua dart-define. Token chỉ memory, logout/reload bỏ session. Navigator riêng theo sessionEpoch: route và response cũ bị loại khi logout/đổi account. Admin token không đưa vào Member/PT.
- GET /api/v1/admin/booking-policy:200 parse DTO thật; chỉ404 BOOKING_POLICY_NOT_FOUND là chưa cấu hình. Form trống, không giả lập14/2/4/5 và không tự PUT. Lỗi GET khác không cho lưu khi chưa đọc được trạng thái.
- PUT chỉ gửi4 JSON integers: maxAdvanceDays>=1,minNoticeHours>=0,cancelDeadlineHours>=0,maxFutureBookings>=1; tất cả<=2147483647. Không thêm business cap/quan hệ giữa trường. Không gửi id/effectiveFrom/lịch tương lai hoặc hồi tố.
- Chỉ200 với DTO hợp lệ và bốn giá trị khớp request mới báo đã lưu. UUID/effectiveFrom có offset được parse, hiển thị giờ Việt Nam độc lập timezone trình duyệt. Tóm tắt dùng policy server, không xem bản nháp là cấu hình đã lưu.
- GET401 refresh tối đa1lần và retry1GET. PUT401 có thể refresh nhưng không replay PUT. Timeout/network/5xx/response write chưa rõ: khóa lưu, yêu cầu GET đối chiếu, không fake success hoặc replay. Double-submit bị chặn; error.code/correlationId được giữ.
- Nội dung trang ghi rõ deadline mới áp cho yêu cầu Member hủy sau cập nhật, kể cả booking đã tạo trước đó. Giảm maxFutureBookings không sửa/hủy booking cũ. Không tạo API hoặc thay contract Backend.

## Môi trường và fixture

Flutter3.50.1/Dart3.14.0, Dart constraint^3.13.5 giữ nguyên. `pub get` cập nhật4 transitive SDK packages (meta,test_api,vector_math,listen), thêm http^1.6.0 và3 transitive cần thiết; không pub upgrade. SDK/Pub cache riêng ngoài Git; không đổi PATH máy. Web JavaScript release đã build/chạy; chưa nghiệm thu Wasm/native.

JDK21.0.13+9, Backend default profile, JVM UTC, loopback18081. Guard kiểm container ID e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0, label baseline-20261120, volume fitcenter_baseline_20261120_data,127.0.0.1:15437→5432, DB fitcenter_baseline_20261120_test, role fitcenter_baseline_app không đặc quyền và canonical Flyway1–6 trước startup. Không alignment/V7.

Chỉ helper [booking-demo.ps1](../../../backend/scripts/booking-demo.ps1) thêm switch IncludeAdminWeb: process CORS mặc định vẫn3000/3001, switch mới thêm chính xác http://localhost:3002. [Static server](../../../frontend/serve-booking-web.mjs) thêm `ad` ở3002, vẫn bind loopback. CORS thực tế cho cả3 origin, từ chối3003; không wildcard/cấu hình môi trường chung.

Seed dùng manifest riêng sẵn có trong Temp, ADMIN/2Member/2PT/plan/memberships tổng hợp và BCrypt thật. Không ghi đè credentials, không dùng AutoCloseable fixture đã cleanup. Lượt đầu policy trống; **cấu hình đầu tiên do Admin UI PUT**, không chạy action Policy trước đó. Runner đăng ký policy UUID response vào manifest ngay khi xác minh thành công; Cleanup kiểm updated_by/ownership và chỉ xóa UUID manifest.

Sau tạo policy đầu tiên, LifecycleSeed tạo6slot/5booking theo giờ thật (current,ended,future24/28/32/36giờ) để có booking trước lần đổi policy. Đây là **seed**, không tuyên bố tạo booking qua UI trong task Admin. Không đổi Clock production/chờ90phút. Task này chỉ thao tác UI hủy một booking future đã seed; không kiểm lại toàn bộ lifecycle UI cũ.

## Kết quả thực chạy

[Evidence tổng hợp đã bỏ credential/raw logs](ADMIN_BOOKING_POLICY_CHECKS.json). Hashes gắn source cuối; UI runtime không đổi sau build. Không cộng lại focused/repeated runs hoặc cộng checks vào Flutter test count.

| Loại | Passed | Failed/errors | Skipped | Ghi chú |
|---|---:|---:|---:|---|
| Admin unit/client/widget — lượt cuối |36|0|0|Auth/role, bounded refresh/PUT no-replay, stale session, DTO/int32,404, PUT success/error/network/timeout, double-submit, logout pending GET/PUT |
| Member regression chạy lại |37|0|0|Helper static server chung được mở rộng; Dart source giữ nguyên |
| PT regression chạy lại |48|0|0|Cùng lý do, không dùng số lịch sử làm lượt vừa chạy |
| Admin analyze |0 errors/0 warnings|0|—|33 infos legacy/deprecation với --no-fatal-infos |
| Admin release web build |1|0|0|--no-web-resources-cdn, API_BASE_URL loopback |
| Static server smoke checks |18|0|0|Ba app:GET/HEAD/no-store/405/không phục vụ manifest |

UI Chrome thật (assertions theo từng pha, có login lặp nên **không cộng thành số tests độc lập**): initial16/0/0; restrict13/0/0; allow13/0/0; feedback8/0/0. Cụ thể:

1. Login Admin → Home gốc → GET404/form trống → UI PUT14/2/4/5 → reload yêu cầu login → GET đọc lại đúng policy UUID.
2. Sau seed booking, UI PUT14/2/48/1. Snapshot DB xác nhận mọi row booking/slot giữ nguyên; >1 booking future vẫn tồn tại. MemberA dùng lịch sử gốc, xác nhận hủy booking cũ →409 ERR_CANCELLATION_DEADLINE, không state giả. [Ảnh](admin-policy/member-new-deadline-conflict.png).
3. UI PUT14/2/0/1 → cùng booking cũ được MemberA hủy200 CANCELLED; DB cancelledBy=MEMBER,cancelledAt có giá trị, slot AVAILABLE; FK/time/owner và mọi booking/slot khác giữ nguyên. [Ảnh](admin-policy/member-new-deadline-allowed.png).
4. Fault injection abort PUT trong browser: một lần gửi, NETWORK_ERROR, khóa lưu; GET đối chiếu200, không PUT tự replay; logout loại route policy. Đây là fault injection client, không phải lỗi mạng production thực.

HTTP probe:11 checks ở mỗi trạng thái restrict/allow, cùng tập quyền/CORS/DTO nên không gọi thành22 tests độc lập:401 không token; MEMBER/PT GET/PUT403;3 origin hợp lệ,3003 bị từ chối; DTO/UTC khớp DB. Negative PUT chỉ kiểm403, không thay policy. DB assertions theo pha baseline2,restrict8,allow11, không gộp với HTTP/UI. [Probe](../../../frontend/verify-admin-policy-demo.mjs), [UI runner](../../../frontend/verify-admin-policy-ui.mjs).

Lỗi đã sửa trong quá trình kiểm tra: test mẫu MyApp sai; tham chiếu scheduling cũ còn sót; hai thông báo missing/reconcile chưa được render; viewport/selector harness không chạm nút cuối trang/menu Member đầy đủ; assertion cancelledBy nhầm UUID thay vì actor string. Các attempt UI lỗi được đối chiếu DB, giữ riêng local; không replay write chưa rõ. Sau selector Member lỗi, cleanup chính xác và bắt đầu chu kỳ fixture sạch. Một test PUT trùng đã bỏ; kết quả cuối là36, không phải37 lượt trước.

Không chạy full Backend: không sửa executable production Backend/POM/migrations. Con số668 là lịch sử, không phải lượt này. Không phát triển Admin modules khác, Membership/Payment/Workout/Face; chưa chứng minh E2E toàn FitCenter hay bảo mật production.

## Cleanup và chạy lại

[Quickstart ba app](../15_BOOKING_WEB_QUICKSTART.md#admin-booking-policy-web). Dừng đúng3Node PID, Java và guarded parent của task; Capture rồi Cleanup hai lần idempotent theo UUID. Kiểm tám bảng users/members/personal_trainers/membership_plans/memberships/availability_slots/bookings/booking_policy đều0, Flyway1–6 thành công. Dừng đúng DB container đã tự khởi động, giữ volume.3000/3001/3002/18081 không còn listen; không dừng container khác. Credentials/manifest/private results/raw logs ở Temp ngoài Git.

Task Admin giữ chưa stage/commit, index rỗng. Không push/merge; checkout gốc, survey untracked và Face giữ nguyên. Artifact evidence phục vụ review, không chứa secret/dữ liệu thật.