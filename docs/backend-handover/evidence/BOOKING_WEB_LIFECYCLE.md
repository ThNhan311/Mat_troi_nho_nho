# Booking Lifecycle — Member/PT Flutter Web

Nghiệm thu 22/11/2026 (các request UI khoảng 2026-11-21T17:35Z–17:44Z, tức22/11 giờ Việt Nam). Lát cắt lifecycle chạy qua UI thật và PostgreSQL riêng; không gọi là E2E toàn FitCenter.

## Source và trạng thái Git

- Đóng slice đầu bằng commit local **9fe34b99324ab53748c495145c1c0d2c8a4abd12**,334 file. Backend gốc089b5e27bda9cc4c543d5d239d3f51377b5e80af; chỉ import hai app từ Frontend0307242a34ceb76a289f7ed1f43653e5a1862948. Đối chiếu trước commit:305file nguồn ghim,291 nguyên nội dung Git,14 sửa,12file app mới;22/22 hashes ban đầu khớp. Helper demo được gia cố và kiểm thử riêng6checks trước commit; không chạy lại Flutter chỉ để commit. [Báo cáo slice đầu](BOOKING_WEB_INTEGRATION.md).
- Nhánh hiện tại **feature/frontend-booking-lifecycle**,HEAD9fe34b9. Lifecycle **chưa stage/commit**, không push/merge. Worktree riêng Mat_troi_nho_nho-booking-integration; checkout gốc vẫn feature/backend-service-eligibility/089b5e2, chỉ survey/Face untracked cũ, tracked diff rỗng.
- [19 executable source/test/helper hashes](BOOKING_WEB_LIFECYCLE_HASHES.json) gắn working tree kiểm thử hiện tại. Không dùng22hashes checkpoint cũ để mô tả source lifecycle mới.
- Phạm vi:12file Dart trong entry/dashboard/client/models/services/time,2file API-client tests sửa,2file lifecycle tests mới,2helper demo sửa,1probe HTTP mới,2README,quickstart,báo cáo/hash và14ảnh lifecycle. Sửa dấu tiếng Việt ở đoạn addendum review vừa thêm của báo cáo slice đầu. Không thay theme/dashboard sang flow mock.
- Production Backend/POM/OpenAPI/migrations không đổi. Đối chiếu contract có sẵn trong [API documentation](../05_API_DOCUMENTATION.md), [OpenAPI](../api/openapi.yaml), [D01](SERVICE_ELIGIBILITY.md). Không thêm endpoint/dependency/migration, không V7/alignment/Admin UI/Membership/Payment/Workout/Face.

## Contract đã nối

| Màn hình / thao tác | API hiện có (prefix /api/v1) | Hành vi client |
|---|---|---|
| Member hủy booking | POST /bookings/{id}/cancel | Xác nhận trước gửi; dùng booking.id;200 DTO CANCELLED/actor/time đúng identity mới cập nhật rồi reload lịch/available. Không tính hạn4giờ ở UI; thiếu policy/409 hiển thị error.code/correlationId |
| PT sửa slot | PATCH /pt/availability/{id} | Giờ input Việt Nam,+90phút; dùng response UUID/time/status. Nếu UUID thay thế thì thay DTO và nút thao tác rồi reload, slot cũ giữ DISABLED/history |
| PT loại slot | DELETE /pt/availability/{id} | Xác nhận;204 không decode JSON. Không tuyên bố xóa vật lý; reload trạng thái server |
| PT hủy session | POST /pt/bookings/{id}/cancel | Reason bắt buộc/không blank; server kiểm now<startAt.200 DTO có cancelledBy/cancelledAt/cancelReason; không fake success |
| PT kiểm tra điều kiện | GET /pt/bookings/{id}/service-eligibility | HTTP200false là dữ liệu; đọc eligible/reasonCodes/checkedAt. Lý do tiếng Việt, có mã gốc, UTC và giờ Việt Nam. Mỗi bấm gọi GET mới; đóng dialog bỏ kết quả |
| PT hoàn tất | POST /pt/bookings/{id}/complete | Xác nhận, server kiểm thời gian/trạng thái.200 DTO COMPLETED/completedAt mới thông báo; không yêu cầu đã GET eligibility |

Chỉ các slot AVAILABLE có nút sửa/loại; booking CONFIRMED mới có nút hủy/complete. Không dùng đồng hồ client để cho phép lifecycle. Server quyết định role/ownership và tất cả deadline. Request dùng UUID/UTC server; query from/to có offset và Uri builder. PT chỉ hiển thị Member UUID rút gọn, không bịa tên/rating.

ApiClient/session memory được giữ: refresh có giới hạn, GET retry tối đa1lần sau refresh; POST/PATCH/DELETE không replay khi401 hoặc lỗi mạng/timeout/kết quả chưa rõ.204 thành công không parse JSON. Session epoch thay đổi khi logout/login, dashboard dùng key theo epoch và bỏ response cũ; refresh cũ không ghi đè phiên mới. Nút khóa khi gửi/đang dialog; write chưa rõ kết quả khóa tới khi manual reload thành công. Không lưu/log token/credential, không fallback mock.

Eligibility chỉ phản ánh snapshot tại checkedAt; không phải start marker/quyền dùng lâu dài. Backend no-store; UI không lưu kết quả sau đóng. Không IN_PROGRESS/startedAt/startedBy. Complete giữ R04, không thêm bước bắt buộc. D01 Backend và UI kiểm tra hiện tại đã nối; không tuyên bố luồng bắt đầu/chặn dịch vụ bắt buộc toàn hệ thống hoàn thành.

## Kết quả thật của source hiện tại

| Nhóm cuối | Passed | Failed/errors | Skipped | Phân biệt |
|---|---:|---:|---:|---|
| Member flutter test |30|0|0|Client/DTO/time + widget, HTTP MockClient |
| PT flutter test |41|0|0|Client/DTO/time + widget, HTTP MockClient |
| Member focused lifecycle |7|0|0|Tập con30; không cộng dồn |
| PT focused lifecycle cuối |18|0|0|Tập con41; không cộng dồn |
| HTTP probe lifecycle |41 checks|0|0|20requests Backend thật; không phải41JUnit tests |
| JDBC/PostgreSQL lifecycle audit |13 checks|0|0|Trạng thái/metadata/FK-time và snapshot không đổi |
| Member analyze --no-fatal-infos |exit0|0error/0warning|N/A|33infos |
| PT analyze --no-fatal-infos |exit0|0error/0warning|N/A|36infos |
| Web JS build Member/PT |2thành công|0|N/A|Bundle mới của lifecycle đã dùng cho UI |
| Backend full regression |không chạy lại|N/A|không cộng skipped|Executable Backend không đổi;668 là lịch sử D01 |

Hai suites có **71 tests riêng**, không cộng focused/repeated runs hoặc HTTP/DB checks. Không gọi widget MockClient là UI thật. Analyzer Member:27deprecations Material SDK,4curly-braces infos,1unnecessary_underscores,1unnecessary_this. PT:22deprecations,11curly-braces,2unnecessary_underscores,1use_build_context_synchronously. Có infos style mới/legacy; không tuyên bố analyzer sạch mọi issue. Context trong eligibility đã được kiểm bởi alive (mounted và session epoch); analyzer không nhận biết getter guard này. Không migrate Material hàng loạt ngoài task.

Tests mới kiểm tra: confirmation bỏ qua không write; chờ response/khóa gửi; booking.id tách slot.id; metadata/identity sai trong200 bị coi kết quả chưa rõ; missing policy/409/network không fake success; PATCH UUID thay thế rồi DELETE dùng UUID mới;204 rỗng; PT reason blank/được lưu; complete độc lập eligibility; HTTP200false/mã lạ/payload inconsistent; GET mới phản ánh thay đổi; lỗi409/network cho từng PATCH/DELETE/cancel/complete không replay; PATCH/DELETE401 refresh một lần không replay; response cũ sau đổi account bị từ chối. Widget có happy path từng thao tác, false eligibility/checkedAt và error state.

Commands thực chạy (SDK riêng Flutter3.50.1/Dart3.14.0, JDK21.0.13+9; không sửa PATH máy):

~~~text
flutter test test/lifecycle_test.dart --reporter expanded  (focused từng app)
flutter test --reporter expanded                         (full từng app)
flutter analyze --no-fatal-infos                          (từng app)
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1
node --check frontend/verify-booking-lifecycle.mjs
booking-demo.ps1: Seed,ServeBackend,Policy,LifecycleSeed,LifecycleSnapshot,LifecycleAudit,Cleanup
node frontend/serve-booking-web.mjs member|pt
node frontend/verify-booking-lifecycle.mjs <private-Temp-manifest>
~~~

## Fixture và UI/DB evidence mới

Guarded runner xác minh JDK21, context desktop-linux local npipe, container e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0,label baseline-20261120,named volume fitcenter_baseline_20261120_data,127.0.0.1:15437→5432,DB fitcenter_baseline_20261120_test,role fitcenter_baseline_app không đặc quyền,Flyway1–6 trước startup. Backend loopback18081/default profile/JVM UTC/CORS đúng localhost3000 và3001. Không mở DB LAN/firewall hoặc tài nguyên khác.

Actor fixture: ADMIN,2Member,2PT,profile riêng,plan/membership,BCrypt thật; credentials/manifest/logs ngoài Git trong private Temp. Policy14/2/4/5 được cấp qua Admin PUT thật, không giao Admin session cho app. LifecycleSeed thêm6slot/5booking theo real now17:35Z: current−30phút,ended−3giờ,future+24/+28/+32/+36giờ. Membership fixtureA bắt đầu từ hôm qua để bao phủ nửa đêm Việt Nam. Không đổi Clock production/chờ90phút. Seeded booking không được gọi là tạo từ UI.

| Scenario (UUID tổng hợp) | Nguồn / thao tác UI thật | Kết quả / bằng chứng |
|---|---|---|
| memberCancel booking998ca0df-7999-457b-ae9d-980d7d9b47e1,slot3fd38bfb-357a-43af-b57a-cfc0649e8d4a |Seed CONFIRMED → MemberA xác nhận hủy |200 CANCELLED/MEMBER/cancelledAt; slot AVAILABLE; [available sau hủy](booking-web/lifecycle-01-member-cancel.png) |
| rebook a64ef076-40c4-4fbb-b71e-dd8a30b7f325 |MemberB tạo qua UI cùng slot |201 CONFIRMED,UTC2026-11-22T17:35Z→19:05Z,slot BOOKED; [thành công](booking-web/lifecycle-02-member-b-rebook.png),[reload/login lại](booking-web/lifecycle-14-reload-member-b.png) |
| ptCancel2de75976-86be-4e31-85d7-bfcf0a705729,slotf57588d4-d369-415c-ac52-744b446300f8 |Seed → UI reason blank bị chặn,reason hợp lệ gửi |200 CANCELLED/PT,cancelReason Demo PT unavailable,cancelledAt;slot DISABLED;[metadata](booking-web/lifecycle-06-pt-cancel.png) |
| replacement history87d89a3f-85cd-4f3d-aaca-68c3bd78bd00,oldslot924bed96-0dde-4899-8ead-7b0543bf30c3 |Seed CANCELLED history/AVAILABLEslot → UI PATCH09:00VN |200 newslotd9d7325f-9a37-4d0c-bb18-1592ebf5d7ba;oldDISABLED/historygiữtime;[ID mới](booking-web/lifecycle-07-replacement-id.png). UI PATCH tiếp chính UUID mới sang09:15VN thành công200,cùngID;UTC2026-11-23T02:15Z→03:45Z |
| delete slot803214fe-1cb3-40b1-8fca-aa3abd004043 |Seed chưa booking → UI DELETE |204 body rỗng;row DISABLED/không còn available;[kết quả](booking-web/lifecycle-08-delete-disabled.png) |
| currentc7818e2f-eb67-4d97-bdc4-49ffc4a27ea8 |Seed session đang diễn ra → UI eligibility |200true,[]reasons,no-store,checkedAt17:37:55.1376651Z;[dialog](booking-web/lifecycle-03-eligibility-true.png). Snapshot booking/slot/account/profile/membership trước/sau bằng nhau |
| future rebook trên |UI eligibility của booking MemberB |200false,SESSION_NOT_STARTED,checkedAt17:38:01.757994Z;[lý do Việt](booking-web/lifecycle-04-eligibility-false.png) |
| ended49463023-b4a8-4346-a8d7-ca6bf8a62762,slotd17251ea-a2a2-4d9a-8d21-ec5834f75899 |Seed session đã hết → UI complete,không gọi eligibility cho nó trước |200 COMPLETED/completedAt17:38:18.9030803Z;slot DISABLED;[kết quả](booking-web/lifecycle-05-completed.png) |
| quyền / account đổi |Member login appPT bị ROLE_MISMATCH;PTA logout rồi PTB login |[Role bị từ chối](booking-web/lifecycle-09-wrong-role.png),[PTB rỗng/không lịchA](booking-web/lifecycle-10-pt-b-isolated.png). Probe kiểm owner404,role403,anonymous401 và lịch từng profile |
| complete quá sớm |UI complete current khi chưaend |409 ERR_BOOKING_NOT_ENDED/correlationId,reload giữCONFIRMED;[lỗi thật](booking-web/lifecycle-13-complete-409.png) |
| network /401 |Browser abort PATCH1lần; sau manual reload thay Bearer GET lịch bằng giá trị test sai |[NETWORK_ERROR](booking-web/lifecycle-11-network-no-replay.png),1write/khóa repeat/no success;2GET401+1refresh rồi[login](booking-web/lifecycle-12-401-login.png) |

Probe HTTP còn kiểm request hủy booking cũ sau rebook trả409 ERR_BOOKING_NOT_CONFIRMED,booking mới vẫn CONFIRMED; MemberB không đặt lại được slot PT cancel DISABLED; PTB không thể hủy/check eligibility bookingA; Member không DELETE availability; MemberA không hủy bookingB. Dữ liệu MemberB/PTB chỉ thuộc đúng profile. Đây là HTTP thật, không tuyên bố tất cả request trái quyền đều thao tác từ UI.

Network injection abort trước khi Backend nhận PATCH, nên không chứng minh trường hợp server commit xong mất response. Cơ chế outcomeUnknown/no replay được kiểm riêng bằng MockClient. Dùng một tab browser tích hợp chuyển origins tuần tự; tab công cụ cũ mất giữa phiên, mở lại/login rồi tiếp tục. Không tuyên bố hai người thao tác UI đồng thời hoặc auto-sync.14ảnh đã xem lại,không password/token/email credential trong ảnh bàn giao.

## Failures đã sửa và giới hạn

- Lần tạo source qua PowerShell pipe đầu dùng encoding ASCII làm hỏng dấu và ký tự; formatter phát hiện trước build/test. Viết lại đúng source thay đổi bằng UTF-8 và chạy focused/full/build mới. Addendum review slice đầu bị mất dấu đã sửa trong working tree hiện tại; không amend commit9fe34b9.
- Focused PT đầu14passed/2failed do tap khi nút ngoài viewport800×600. Thêm ensureVisible và pump sau cuộn; focused cuối18/18,full41/41,không skip ca lỗi.
- Audit DB đầu thất bại ở assertion cuối vì JDBC boolean trả t; cast PostgreSQL boolean sang text rồi kiểm lại. Audit cuối13/13. Đây là lỗi helper assertion,không lỗi state Backend.
- Analyzer còn infos nêu trên,không error/warning; build JS không phải Android/iOS/Wasm. Không load/performance/fullBackend regression hoặc E2E toàn hệ thống.
- Thiếu policy/ranh giới deadline/401 write/timeout/malformed success được bao phủ client/widget; không xóa policy hay đổi thời gian Backend để giả ca UI thật. Backend R04/D01 tests668 là evidence lịch sử riêng.
- Range vẫn now−1ngày→now+31ngày,refresh chủ động; không thêm persistent session/public policy/memberName/Admin UI. D01 chỉ kiểm tra,không lưu bắt đầu hoặc bắt buộc trước complete.

## Cleanup và chạy lại

[Quickstart cập nhật](../15_BOOKING_WEB_QUICKSTART.md) có thứ tự seed/scenario/UI/probe/audit/cleanup. LifecycleSeed đăng ký UUID trước INSERT để phục hồi; Capture đăng ký thêm booking rebook/slot thay thế; Cleanup khóa và kiểm lại owner mọi UUID rồi xóa trong transaction,không truncate/broad delete. Không ghi đè credential/resource ngoài fixture.

Cuối phiên đã logout,đối chiếu PID/command line và dừng BackendJava3232+2Nodeservers24888/24960,launcher14948 tự thoát. Ports18081/3000/3001 không còn listener. Cleanup xóa đúng7slot/6booking cùng actors/profiles/membership/plan/policy; cleanup lặp an toàn. SQL cuối users,members,PT,plans,memberships,slots,bookings,policy đều0;Flyway1,2,3,4,5,6|true. Đã stop đúng container test,giữ volume. Hai container khác và Docker engine được giữ nguyên.

Credentials/manifest/rawlogs/SDK/cache/build chỉ local ngoài danh sách Git. Source Face và survey untracked ở checkout gốc giữ nguyên. Lifecycle để unstaged/uncommitted cho review.
