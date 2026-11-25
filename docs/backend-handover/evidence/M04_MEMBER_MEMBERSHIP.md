# M-04 — Member Membership trên UI gốc

Kiểm chứng thực ngày23/11/2026, branch `feature/member-membership-read`, source base `0c31947b60bacbb7d7516556a7f2b44193ec86a8`. Commit bàn giao chứa working tree này; xem Git cho SHA cuối. Không thay Backend, schema, Booking hoặc activation; không áp V7/V8 vào DB demo.

## Contract và giao diện

[MembershipService Backend](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/service/MembershipService.java) trả array DTO `{id,planId,planName,startDate,endDate,status}` qua GET `/api/v1/memberships/me`. Owner lấy từ principal→users.id→members.id, không client memberId. Repository không có ORDER BY hoặc contract chọn current/next. V2 chỉ giới hạn tối đa một row chưa CANCELLED, vẫn có nhiều row CANCELLED. UI hiển thị **toàn bộ danh sách**, không chọn phần tử đầu, không tự phân loại kỳ hiện tại/kế tiếp.

Backend chuyển ACTIVE thành PENDING_ACTIVATION khi chưa đến startDate/null date, EXPIRED khi expiry trước hôm nay theo Asia/Ho_Chi_Minh; ngày expiry bằng hôm nay vẫn ACTIVE. Không persist trạng thái tính toán này. Dart giữ DATE `yyyy-MM-dd` như lịch, hiển thị dd/MM/yyyy và nhãn Việt từ status server, không đổi qua timezone máy hay suy trạng thái bằng đồng hồ client.

[Home/navigation](../../../frontend/fitcenter_member/lib/screens/home_page.dart) dẫn tới [MembershipPage gốc](../../../frontend/fitcenter_member/lib/screens/membership_page.dart), giữ header/theme/card/icon và navigation. Thay nội dung mẫu bằng list/UUID/ngày/trạng thái, null date là Chưa xác định. Bỏ số buổi, số ngày còn lại, giá, paidAt và lịch sử thanh toán giả; Gia hạn/thanh toán báo Chưa khả dụng. Không đổi module RenewalPaymentPage chưa tích hợp, không có đường vào nó từ Membership vận hành.

[Client/DTO](../../../frontend/fitcenter_member/lib/services/membership_service.dart) tái sử dụng ApiClient/session memory/refresh giới hạn. Load khi mở tab, reload thủ công, không write. Refresh bỏ dữ liệu cũ, loading/error/empty riêng; epoch và request ticket loại response cũ khi logout/đổi account. Navigator theo phiên giữ nguyên. Không thêm endpoint hoặc mock fallback.

## Kết quả thực chạy

| Loại | Kết quả cuối | Phạm vi |
|---|---|---|
| Member unit/client/widget | **52 passed /0failed /0skipped** | Toàn bộ suite Member, gồm15 focused M-04; không cộng15 vào52 |
| Analyze cuối | exit0 với `--no-fatal-infos`;0error/0warning/**44info** | SDK3.50.1 báo Material deprecated và style; strict analyze trước đó exit1. Không tuyên bố lint hoàn toàn sạch |
| Web build | passed | JavaScript release với API_BASE_URL18081; Wasm dry run thành công, chưa nghiệm thu Wasm/native |
| Chrome UI thật | **19 passed /0failed /0skipped checks** | Login gốc→Membership,3rows, đủ nhãn status/null dates, reload/login, logout gốc→MemberB empty |
| HTTP thật | **14 passed /0failed /0skipped checks** | Owner/query isolation,401/403,7 trường hợp status/DATE, empty/multiple |
| PostgreSQL audit | **10 passed checks** |7 stored statuses không bị GET persist, UI DTO=DB, non-membership snapshot, ngoài UUID fixture không đổi |
| Cleanup | **4 passed checks**, chạy lại cũng đạt | Khôi phục rows ban đầu và snapshot ngoài fixture; không cộng lượt lặp thành8 |

[Checks, cặp DTO/DB, toolchain và source hashes](M04_MEMBER_MEMBERSHIP_CHECKS.json) là evidence có cấu trúc, không raw logs. Hash bao phủ tất cả Dart lib/test Member, pubspec/lock và runners; five changed/new executable files nằm trong đó. Tests52 chạy trên Dart cuối, UI/HTTP/DB chạy lại sau sửa helper evidence cuối. Không chạy lại Backend801, Admin/PT tests hoặc PT activation vì executable/shared code của chúng không đổi;801 là kết quả lịch sử trong [rehearsal](PT_ACTIVATION_POSTGRES.md), không phải lượt này.

[Tests M-04](../../../frontend/fitcenter_member/test/membership_test.dart) kiểm DTO/UUID/array/date/status, malformed response, loading/empty/manual reload/error+correlationId/offline, bounded refresh401, logout/account switch khi response đang chờ. Lỗi mạng/401/stale responses thuộc client/widget với MockClient; không gọi các case đó là HTTP server thật. UI thật dùng Chrome cài trên máy,1024×768, timezone America/Los_Angeles; không response interception/mock trong runner M-04.

## Fixture và bằng chứng UI/DB

Mọi User/Membership trong demo là fixture SQL tổng hợp; MEMBER ACTIVE do seed, **không phải đã triển khai kích hoạt MEMBER**. Base fixture có ADMIN,2MEMBER,2PT,plan,membership; BCrypt bằng encoder thật. M-04 chỉ seed thêm2 CANCELLED cho MemberA; thay đổi riêng rowA để thử ACTIVE(start=expiry=today), ACTIVE tương lai/hết hạn, PENDING/null,SUSPENDED,EXPIRED,CANCELLED; tạm bỏ membershipB để UI empty. Đây là setup trực tiếp SQL, không phải thao tác activation/renewal/payment qua UI.

Runner giữ registry/snapshot/credential ở Temp, ghi UUID trước INSERT bằng `wx`, không ghi đè run cũ. Guard containerID/label/volume/loopback15437/database/role không quyền admin/history1–6 trước SQL. Không truncate/broad delete; cleanup đúng UUID+member_id+plan_id, phục hồi đầy đủ rows bằng INSERT trong transaction, đối chiếu snapshots. Sau scenario cleanup chạy BookingDemo Cleanup cho exact base UUIDs. Không có policy PUT hoặc booking tạo mới trong task này.

- [Danh sách ACTIVE+CANCELLED, cùng ngày bắt đầu/kết thúc](member-membership/multiple-active-cancelled.png).
- [PENDING/null dates và Gia hạn chưa khả dụng](member-membership/pending-null-dates.png).
- [Reload/login đọc lại từ server](member-membership/relogin-persisted.png).
- [MemberB empty sau đổi account](member-membership/member-b-empty.png).

Cặp UUID/date/status PostgreSQL và UI HTTP response ghi trong `readback` của checks JSON. Browser UI cũng kiểm UUID được hiển thị qua semantics và ảnh; không chỉ kiểm HTTP200. GET không đổi account/profile/plan/payment/booking/slot/policy, kể cả stored ACTIVE đang được API trình bày EXPIRED/PENDING. Không kiểm current/next periods vì contract hiện tại chưa có.

## Lỗi đã xử lý và giới hạn

Docker daemon ban đầu tắt: khởi động Docker Desktop hiện có rồi guard đúng container test. Đường dẫn Playwright cũ mất: cài1.56.1 riêng Temp, không thêm dependency repo. UI assertion đầu chỉ đọc viewport nên thiếu UUID/phần Gia hạn dưới vùng cuộn: thêm nhãn accessibility UUID và quét vùng cuộn, tests/build/UI cuối đạt; không dùng lượt lỗi làm evidence thành công. Ảnh pending được chụp đúng vùng cuộn có null dates, chạy lại helper cuối. Không sửa business Backend để tránh lỗi mapping.

Own Backend/web wrappers/Java/container đã dừng, ports3000/18081/15437 không còn listener, volume giữ nguyên. Docker Desktop giữ chạy vì có containers ngoài FitCenter; không dừng/sửa tài nguyên đó. Default activation vẫn tắt theo source/JAR profile default, không gọi lại OTP/rehearsal hoặc production mail. Bốn research untracked/Face giữ ngoài staged scope.

Trước push: fetch refs; nhánh remote M-04 chưa tồn tại. Repo không có tracked CI config/non-sample hooks; GitHub API metadata hiện0workflows/0runs/0deployments/0webhooks. Đây là kiểm tra cấu hình, không phải CI pass. Commit/push nhánh chức năng theo quyền đã giao, không merge. [Cách chạy lại](../17_MEMBER_MEMBERSHIP_READ_QUICKSTART.md).
