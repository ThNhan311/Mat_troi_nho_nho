# Booking Web — kết quả tích hợp Member/PT

Ngày nghiệm thu 21/11/2026. Lát cắt login → PT tạo availability → Member đọc PT/slot, đặt auto-confirm → đọc lại lịch hai bên đã chạy trên UI thật với Backend/PostgreSQL riêng. Không phải E2E toàn FitCenter.

## Nguồn, nhánh và phạm vi

- Backend base/HEAD: 089b5e27bda9cc4c543d5d239d3f51377b5e80af.
- Frontend source ghim: 0307242a34ceb76a289f7ed1f43653e5a1862948, chỉ frontend/fitcenter_member và frontend/fitcenter_pt.
- Nhánh: feature/frontend-booking-integration. Worktree bàn giao riêng: D:/Workspace/HKI_26_27/CNPM_project/Mat_troi_nho_nho-booking-integration. Chưa stage/commit/push/merge.
- Checkout gốc vẫn feature/backend-service-eligibility/089b5e2; survey untracked và Face giữ nguyên. Survey gốc và bản giữ trong worktree có SHA256 554D9DEED4148C71A0B6CC0AE6628784A711617CD582E553D1B4435C305532CD. Không reset/stash/checkout đè nhánh đồng đội.
- Không tìm thấy AGENTS.md trong các ancestors/cây liên quan đã kiểm tra, kể cả ancestors của worktree tạm và hai ứng dụng nguồn. Tạo nhánh từ đúng base, kiểm tra target chưa tồn tại và hai thư mục không collision trước git archive; không merge nhánh frontend hoặc mang Backend/database cũ vào.
- Ban đầu dùng worktree trong sandbox Temp; đã chuyển nguyên trạng sang sibling worktree bàn giao và git worktree repair. Enforce-lockfile/analyze/tests được chạy lại tại đường dẫn bàn giao. Source bundle UI không đổi vì việc chuyển vị trí.

Đối chiếu Git source, có **305 file nguồn ghim, không thiếu file**. Sau chuẩn hóa CRLF theo Git, **14 file nguồn sửa**, **12 file mới trong hai app**. Nội dung native scaffolding và prototype ngoài flow được giữ; không phát triển Membership/Payment/Workout/Face. [Provenance và 22 SHA256 executable/test/helper](BOOKING_WEB_SOURCE_HASHES.json) mô tả chính xác file sửa/thêm; hashes là byte working tree thực tế, không hash đã chuẩn hóa.

Các thay đổi chức năng:

- Hai entry points dùng [Member dashboard](../../../frontend/fitcenter_member/lib/screens/booking_dashboard.dart) và [PT dashboard](../../../frontend/fitcenter_pt/lib/screens/booking_dashboard.dart), giữ theme gốc. Không đi vào demo home/luồng mock cũ và không fallback mock khi lỗi.
- Client/session memory riêng từng app: API_BASE_URL qua dart-define, login thật/role đúng, Bearer, logout/reload. GET401 chỉ refresh1lần rồi retry1GET; concurrent GET dùng chung refresh. POST401 refresh nhưng không gửi lại POST. Không log/persist token/credential.
- Timeout/mất mạng/5xx/response write sai hoặc chưa rõ: không báo thành công, không tự replay, khóa gửi tới khi người dùng tải lại để đối chiếu. 409 bỏ selection/reload và giữ error.code/correlationId.
- PT GET own slots/bookings có from/to; POST availability chỉ startAt/endAt, end=start+90phút. Client PT không còn gọi API Member. Lịch dùng member UUID rút gọn.
- Member catalog/detail/available dùng UUID thật, POST bookings chỉ ptId/slotId; chỉ201/CONFIRMED mới báo thành công, refresh available/bookings. Không PENDING/REJECTED/approval.
- Tất cả query dates dùng Uri queryParameters, ISO UTC cóZ; hiển thị cố định Việt Nam UTC+07:00, parse input theo +07:00, không dùng local timezone máy.
- Bốn chỉnh sửa nhỏ ngoài entry mới chỉ dọn warning khi import source: bỏ3 unused imports trong Member home/home_screen/schedule và2 helper không dùng trong PT confirmed_sessions. Không đổi nghiệp vụ prototype.
- Thêm [fixture Java CLI](../../../backend/scripts/BookingDemo.java), [guarded runner](../../../backend/scripts/booking-demo.ps1), [loopback static server](../../../frontend/serve-booking-web.mjs), [probe HTTP](../../../frontend/verify-booking-demo.mjs), cập nhật hai README và [quickstart](../15_BOOKING_WEB_QUICKSTART.md).

Production Backend, cấu hình ứng dụng, POM và database/migrations không đổi. Không thêm endpoint/dependency Backend, không sửa V1–V6/ápV7. Hai pubspec constraints không đổi. Flutter pub get chỉ cập nhật4 transitive SDK dependencies bắt buộc: meta, test_api, vector_math, listen; không pub upgrade hàng loạt.

## SDK và môi trường thực chạy

Flutter3.50.1 stable, framework ae9b586f34; Dart3.14.0. SDK tải từ Google Flutter release manifest/bundle chính thức và kiểm SHA256 33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb trước giải nén. SDK riêng tại C:/Users/Admin/AppData/Local/Temp/vscode-agent-codex-sandbox-7lvCgc/flutter-sdk-tools/flutter. Không sửa PATH máy; cache Pub riêng cùng sandbox.

flutter --version, doctor -v, devices đã chạy. Doctor thấy Chrome157/Edge157 và Windows target; Web sẵn sàng, Android SDK/C++ desktop workload còn thiếu. SDK không nằm PATH là chủ đích. UI thực tế được chạy bằng release Web build phục vụ qua Node, điều khiển trong trình duyệt tích hợp của VS Code, không phải flutter test hoặc HTTP mock. Không tuyên bố đã chạy Android/iOS/Wasm hay Chrome/Edge ngoài trình duyệt tích hợp.

Backend Temurin JDK21.0.13+9, JVM UTC, default profile, loopback18081; CORS đúng localhost3000/3001. PostgreSQL test17.x qua Docker desktop-linux local npipe; container ID:
e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0.
Label baseline-20261120, volume fitcenter_baseline_20261120_data, port127.0.0.1:15437→5432, DB fitcenter_baseline_20261120_test, app role fitcenter_baseline_app không đặc quyền. Xác minh identity/history/privileges trước startup vì Flyway tự chạy. Lần restart kiểm cả jar có đúng6 migration, SHA khớp canonical source, không V7/stale resource.

Fixture persistent riêng: ADMIN,2Member/profile,2PT/profile, plan/membership ACTIVE, email example.invalid, BCryptPasswordEncoder thật. Manifest UUID/credentials và DB password DPAPI chỉ ở thư mục local riêng C:/Users/Admin/AppData/Local/Temp/vscode-agent-codex-sandbox-7lvCgc/booking-demo-local, ngoài Git; không nêu giá trị trong báo cáo. JWT chỉ memory. Policy14/2/4/5 được cấu hình bằng Admin login/PUT thật, không GET fallback. HTTP baseline AutoCloseable không được dùng làm tài khoản demo.

## Kiểm thử thực sự chạy

| Nhóm, lượt cuối | Passed | Failed/errors | Skipped | Ý nghĩa |
|---|---:|---:|---:|---|
| Member flutter test |19|0|0|12 API/session/DTO/time tests +3 write-response tests +4 widget tests, dùng MockClient |
| PT flutter test |19|0|0|12 API/session/DTO/time +3 write-response +4 widget tests, dùng MockClient |
| Focused HTTP probe |26 checks|0|0|19 requests tới Backend thật, không26 JUnit tests |
| Member analyze --no-fatal-infos |exit0|0error/0warning|không áp dụng|29 infos |
| PT analyze --no-fatal-infos |exit0|0error/0warning|không áp dụng|24 infos |
| Member Web JavaScript build |thành công|0|không áp dụng|API_BASE_URL loopback, local web resources |
| PT Web JavaScript build |thành công|0|không áp dụng|cùng cấu hình |
| Backend full regression |không chạy lại|không áp dụng|không gộp vào skipped|production source không đổi;668 là lịch sử D01 |

Không cộng focused/repeated runs vào lượt cuối. Hai Flutter suites có38 tests riêng tổng cộng, không cộng thành706 với baseline Backend668. HTTP probe26 là assertions của một script, tách khỏi unit/widget và UI thật.

29 Member infos gồm26 deprecated_member_use và3 legacy style infos;24 PT gồm21 deprecated_member_use và3 legacy style infos. Không bỏ qua errors/warnings; SDK mới deprecate Material import trong cả source cũ/mới, chưa migrate hàng loạt sang material_ui ở task này. Web build thông báo Wasm dry-run succeeded, nhưng target được build/chạy là JavaScript, không Wasm.

Widget/mock coverage: thiếu API_BASE_URL, role mismatch, logout/memory, refresh1lần, concurrent refresh, logout trong refresh, POST401 không replay, network/timeout, nested error/correlation/URI encoding, UUID và offset, DATE input Việt Nam/overflow, malformed201/unexpected200/500 không thành công giả; screens loading/empty/error, chống double-submit, refresh sau201,409 bỏ selection, PT chỉ gọi đúng namespace, không mock fallback. Các test này không được gọi là UI/HTTP thật.

Commands chính đã chạy:

~~~text
flutter --version
flutter doctor -v
flutter devices
flutter pub get                  (lượt đầu, giữ constraints)
flutter pub get --enforce-lockfile (lượt cuối ở worktree bàn giao)
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1
mvnw.cmd -B -ntp -DskipTests package
mvnw.cmd -B -ntp dependency:build-classpath -Dmdep.outputFile=<private-local-classpath>
booking-demo.ps1: Seed, ServeBackend, Policy, Capture/Audit, Rotate, Cleanup
node frontend/serve-booking-web.mjs member|pt
node frontend/verify-booking-demo.mjs verify <private-manifest> <UI-booking-id>
node frontend/verify-booking-demo.mjs claim <private-manifest> <selected-slot-id>
~~~

Raw analyzer/test/build/HTTP logs giữ local ngoài Git; nguồn và cách chạy lại ở quickstart. Không Maven clean/repair/onboarding BLOCKED/alignment/V7.

## UI thật và DB đối chiếu

| Scenario thực chạy | Kết quả |
|---|---|
| PT login, đọc slots/bookings, tạo slot14:00 Việt Nam90phút |201/AVAILABLE, UUID/time thật, reload list; [ảnh1](booking-web/01-pt-created-slot.png) |
| Member login → catalog/detail PT → available → đặt slot14:00 |201/CONFIRMED, refresh lịch và loại slot khỏi available; [ảnh2](booking-web/02-member-booking-confirmed.png) |
| PT refresh session/slot |Cùng booking UUID, slot BOOKED, Member ID rút gọn; [ảnh7](booking-web/07-pt-refreshed-booking.png) |
| Reload Member, login lại |Không giữ session memory; booking tải lại từ server; [ảnh4](booking-web/04-member-after-reload-login.png) |
| MemberB/PTB ownership |B chỉ thấy bookingB, không bookingA; PTB không slot/bookingPTA; [ảnh6](booking-web/06-member-b-own-booking.png), [ảnh9](booking-web/09-pt-b-no-a-data.png) |
| Stale selection409 |MemberA chọn slot10:00; HTTP MemberB đặt trước; UIA POST nhận ERR_SLOT_NO_LONGER_AVAILABLE/correlationId, selection rỗng, available reload rỗng, không booking trùng; [ảnh3](booking-web/03-member-conflict-409.png) |
| GET401 qua Backend thật |Browser thay Bearer của GET lịch bằng giá trị không hợp lệ:2GET401,1refresh, rồi logout; không vòng lặp; [ảnh5](booking-web/05-member-401-returns-login.png) |
| POST lỗi mạng trên UI |Browser abort1request PT availability: báo NETWORK_ERROR/kết quả chưa rõ, không fake success, khóa gửi tới reload; không slot mới trong DB; [ảnh8](booking-web/08-pt-network-unknown-result.png) |
| Logout PT |Về login và xóa session; không giữ dữ liệu A khi login PTB |

Browser injection chỉ phục vụ test trên transport, không thêm endpoint hoặc response giả trong app. Case401 nhận response thật từ Backend; case mạng abort trước khi request tới Backend, nên không chứng minh server đã commit rồi mất response. Khả năng timeout/malformed response được kiểm riêng bằng MockClient; không gán chúng thành ca UI đã chạy. UI dùng một tab hoạt động, chuyển tuần tự hai ứng dụng/origins sau khi tab phụ của công cụ nhập liệu không ổn định; không tuyên bố đã kiểm auto-sync hoặc hai người dùng thao tác đồng thời.

Hậu kiểm SQL read-only trước cleanup, khớp UUID/time UI và HTTP probe:

| Trường | BookingA, tạo từ UI MemberA | BookingB, chuẩn bị409 bằng HTTP |
|---|---|---|
| booking UUID |608c169f-f3c9-42b4-aa18-b9c087044752|e5c860b7-7ac0-4f33-9696-fe9de83be7f4|
| member profile UUID |d0c3896e-926b-4c5c-8403-6b732e206bf0|7873b83a-5d2e-4aa6-929d-047298a42c02|
| PT profile UUID |cf391025-9991-47c0-aec5-973f03f71b37|cf391025-9991-47c0-aec5-973f03f71b37|
| slot UUID |da8da5cf-fdb2-4c97-ae0b-c57f66fd1010|b0c67c09-2c2b-4eff-9aef-c7ccf11c524a|
| UTC start/end |2026-11-22T07:00Z /08:30Z|2026-11-22T03:00Z /04:30Z|
| trạng thái booking/slot |CONFIRMED/BOOKED|CONFIRMED/BOOKED|
| FK PT/start/end khớp slot |true|true|

Tổng2slot/2booking, không slot16:00 từ request mạng lỗi. MemberA lịch1, MemberB lịch1, PTA lịch2, PTB lịch0. Probe cuối26checks/19requests thành công lúc2026-11-21T15:56:56.784Z; các probe trước không cộng dồn. Đây là UUID tổng hợp, không dữ liệu thật.

## Lỗi đã xử lý và giới hạn

- PT widget test ban đầu thất bại do ensureVisible trên child chưa dựng, sau đó scrollUntilVisible chọn nhiều Scrollable. Sửa locator tới Scrollable ngoài cùng; lượt cuối19/19, không skip ca lỗi.
- Analyzer ban đầu có3 unused imports Member và2 unused PT helpers; dọn đúng phần thừa. Style fixes chỉ trong code/tests mới. Legacy infos giữ được báo rõ.
- CLI JDBC ban đầu SQLSTATE22023 và sau đó lỗi quote đối số JVM trong PowerShell; cố định JVM UTC/quote đúng, seed/cleanup và restart cuối chạy thành công. Không nêu SQL/stack/secret trong lỗi HTTP hoặc báo cáo.
- Tự động điền form lần đầu chưa focus đúng Flutter editing state; snapshot công cụ đã hiện một credential fixture. Đã xóa field và Rotate toàn bộ credentials fixture trước tiếp tục; credential đó đã vô hiệu, không đưa vào file Git/báo cáo. Các ảnh bàn giao chụp sau login hoặc form trống. Cuối task toàn bộ actor fixture bị cleanup.
- Không còn blocker cho phạm vi Web này. Chưa auto-sync, range picker, persistent session hoặc client sharing package; refresh chủ động. SDK/tools nằm local riêng, cần dùng đường dẫn tương ứng khi chạy lại.
- Chưa PATCH/DELETE availability, cancel/complete/eligibility UI, Admin UI/public policy read, memberName cho PT, Membership/Payment/Workout/Face. Không làm mới state/rule/API. D01 Backend vẫn phương ánA không start marker; complete vẫn R04.
- Không build/chạy native, Wasm, load/performance hoặc E2E toàn hệ thống; không gọi các phần chưa chạy là passed/skipped của Flutter.

## Cleanup và trạng thái bàn giao

Đã Capture chính xác2booking/2slot vào manifest trước cleanup. Seed lặp khi còn dữ liệu báo no-op. Cleanup chu kỳ UI xóa từng UUID trong transaction. Sau đó seed lại cùng manifest → restart Backend với jar guard V1–V6 → Admin PUT → cleanup; cleanup thêm lần nữa no-op an toàn. Không truncate/xóa theo range hoặc reset DB.

Read-only hậu kiểm cuối: users=0,members=0,personal_trainers=0,membership_plans=0,memberships=0,availability_slots=0,bookings=0,booking_policy=0,audit_logs=0. Flyway history1,2,3,4,5,6|true. Giữ volume.

Đã dừng đúng Backend Java và2Node static servers sau kiểm PID/command line, DB container exited. Không container khác bị stop/chỉnh sửa. Docker Desktop/engine được giữ chạy vì có container khác đang sử dụng; không dừng engine chung chỉ để hoàn nguyên phiên demo.

Không còn server demo trên18081/3000/3001. Credentials/manifest/local logs không vào Git; SDK/cache giữ riêng. Worktree bàn giao để review, index rỗng; không commit/push/merge. [Quickstart](../15_BOOKING_WEB_QUICKSTART.md) và hai README chỉ rõ cách dựng lại.

## Review ??ng l?t c?t ? 22/11/2026

?? ??i chi?u 22/22 hashes ban ??u, 305 file ngu?n ghim (291 nguy?n n?i dung Git,14 s?a),12 file app m?i,334 file thu?c task; xem ??9 ?nh, kh?ng credential/d? li?u th?t/Face/SDK/build/cache trong danh s?ch. Source Flutter v? b?ng ch?ng19+19 tests/build/UI kh?ng ??i, kh?ng ch?y l?i ch? ?? commit.

Review ph?t hi?n helper c?n b?o v? manifest c?/sai: Cleanup nay kh?a v? x?c minh ownership m?i slot/booking ?? ??ng k? tr??c DELETE, th?m ?i?u ki?n owner v?o DELETE; Policy t? ch?i policy kh?ng thu?c manifest/admin fixture tr??c HTTP PUT. Kh?ng ??i executable Backend. SHA helper ?? c?p nh?t;21 hashes kh?c gi? nguy?n. Focused Java/JDBC tr?n JDK21/PostgreSQL ri?ng:6 checks passed,0 failed,0 skipped ? t? ch?i UUID slot ngo?i fixture, gi? slot ??, rollback gi?5actor fixture, t? ch?i policy ngo?i fixture, gi? policy ??, cleanup fixture r?i l?p cleanup an to?n tr? users=0. Rows ki?m th? t?ng h?p ri?ng ???c x?a b?ng UUID trong finally. Kh?ng l?y b?ng ch?ng UI c? l?m ch?ng minh guard m?i.

Kh?ng c? push/merge. Commit local ??ng slice ???c t?o sau review theo y?u c?u; tr?ng th?i ?ch?a commit? ph?a tr?n m? t? checkpoint b?n giao21/11. DB ri?ng ?ang ch?y ?? task lifecycle ti?p n?i; volume gi? nguy?n.
