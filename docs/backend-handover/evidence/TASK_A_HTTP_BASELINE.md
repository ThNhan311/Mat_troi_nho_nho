# Kết quả Task A fixture và HTTP baseline

Ngày kiểm tra: 20/11/2026. Đây là kết quả vừa chạy trên máy tiếp nhận, không phải số liệu Task 04 lịch sử. Phạm vi là HTTP integration của các API backend đã có và vòng đời fixture; không phải E2E toàn hệ thống.

## Working tree được kiểm thử

- Branch: `feature/backend-http-baseline-fixtures`, tạo từ `reception/backend-baseline-20261120`.
- HEAD/base: `8eebb9b9192d092f5a4080e853aa739ba582a308`.
- Ba file executable bên dưới là thay đổi mới, chưa commit; production source, POM và migrations không đổi. Hai file tài liệu ghi hướng dẫn và kết quả, không thay đổi runtime được kiểm thử.
- Không stage, commit, push hoặc merge. Môi trường Face untracked được giữ nguyên.

| File mới | Vai trò |
|---|---|
| [HttpBaselineFixture.java](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineFixture.java) | Seed tổng hợp theo V1–V6, BCrypt thật, cleanup bằng UUID riêng |
| [HttpBaselineTest.java](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java) | HTTP thật, payload, quyền, ownership, filters và lifecycle |
| [test-http-baseline.ps1](../../../backend/scripts/test-http-baseline.ps1) | JDK/container/volume/port/datasource preflight và chạy suite |
| [14_HTTP_BASELINE.md](../14_HTTP_BASELINE.md) | Hướng dẫn chạy lại, fixture, coverage và giới hạn |
| TASK_A_HTTP_BASELINE.md | Báo cáo này |

SHA256 của executable files đã được chạy (bytes working tree, trước mọi chuyển đổi LF/CRLF khi Git stage):

| File | SHA256 |
|---|---|
| HttpBaselineFixture.java | `3836A330F111B3EEE2F91C7A578E43EFD64EC0117BD123DFBE3F27002D77E78A` |
| HttpBaselineTest.java | `11C0819786248D5FA887F1257FFAB88B2D4A0FC96362EA548F91D52896C4F77F` |
| test-http-baseline.ps1 | `5FA6F4C3A0248998BF1C237D3A57C9C909D3D1EBB94B287DE5C0CA59F48E65AA` |

## Môi trường đã xác minh

- Temurin JDK 21.0.13 portable; Maven Wrapper 3.10.0; JVM UTC. Java mặc định hệ thống vẫn là 25, không được dùng cho các lượt này.
- Docker context `desktop-linux`, local named pipe `npipe:////./pipe/dockerDesktopLinuxEngine`.
- Container `fitcenter-baseline-20261120-db`, ID `e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0`, label `fitcenter.task=baseline-20261120`.
- Named volume `fitcenter_baseline_20261120_data`, mount `/var/lib/postgresql/data`; mapping chỉ `127.0.0.1:15437`.
- PostgreSQL 17.12; target `fitcenter_baseline_20261120_test`; application role `fitcenter_baseline_app`, không superuser/createdb/createrole/replication/bypassrls, có CREATE schema.
- URL được xác minh: `jdbc:postgresql://127.0.0.1:15437/fitcenter_baseline_20261120_test`. Database dev không được dùng trong Task A.
- Flyway history trước và sau chỉ V1,V2,V3,V4,V5,V6, tất cả success. Không alignment, V7, repair/clean hoặc script onboarding BLOCKED.

## Kết quả cuối cùng

| Lượt | Passed | Failures | Errors | Skipped | Kết thúc UTC |
|---|---:|---:|---:|---:|---|
| Focused HttpBaselineTest | 71 | 0 | 0 | 0 | 2026-11-20 09:54:00 |
| Full suite, RUN_DB_TESTS=true và RUN_HTTP_BASELINE_TESTS=true | 285 | 0 | 0 | 0 | 2026-11-20 09:54:27 |

Full suite gồm 214 tests hiện hữu và 71 test invocations mới. 71 của focused nằm trong 285 của full; không cộng hai lượt. Số test là số JUnit invocations, không phải số HTTP requests; hai ca mới kiểm tra fixture lifecycle. Surefire XML là evidence cục bộ, nằm trong thư mục target được gitignore và sẽ được ghi lại khi chạy tiếp.

Các nhóm trong 71 test invocations:

- 13 ca xác thực: login cả năm actor, sai mật khẩu/thiếu input, refresh ba role, token type misuse.
- 30 ca ma trận role trên mười đường dẫn GET và 10 ca ẩn danh.
- 6 ca ownership/profile: MEMBER A/B booking và membership; PT A/B booking và slots.
- 6 ca lọc trạng thái slot/booking; 4 ca range/empty/validation/not-found, mỗi ca có nhiều assertions/requests.
- 2 ca fixture lifecycle: tạo/dọn lại giữ nguyên ID của dữ liệu có sẵn; từ chối cascade notification ngoài fixture và rollback các DELETE đã thực hiện.

Ca cho phép đọc so sánh ID, owner profile, thứ tự, timestamps, status và các trường DTO; không chỉ kiểm tra HTTP 200. Payload expectation xuất phát từ các giá trị fixture dùng để INSERT trên PostgreSQL thật; FK/CHECK/index thực của V1–V6 vẫn được bật.

Kiểm tra runner bổ sung: 2/2 guard probes đạt; container ID sai và JDK 25 đều bị từ chối trước SQL/Spring. Exit nonzero trong hai probe này là kết quả mong đợi, không phải test backend thất bại. PowerShell parser và whitespace check các file mới đạt. Lệnh gọi trực tiếp ps1 bị ExecutionPolicy Restricted; lệnh chạy được ghi trong hướng dẫn dùng PowerShell con, không thay đổi policy hệ thống.

## Hậu kiểm dữ liệu và tài nguyên

Sau focused và full chạy liên tiếp trên cùng database, users/members/personal_trainers/membership_plans/memberships/availability_slots/bookings/notifications đều còn 0 dòng, bằng trạng thái ban đầu. Không truncate/reset database hoặc xóa volume. Test tái lập còn xác nhận dữ liệu fixture thứ nhất tồn tại nguyên tập ID sau khi fixture thứ hai được seed/cleanup.

Mật khẩu role test được cấp ngẫu nhiên trong process khi chạy; runner không tự đổi mật khẩu. Mật khẩu actor, BCrypt hashes và JWT không được chép vào Git hoặc báo cáo. Không chia sẻ nguyên docker inspect, request/response dump hoặc môi trường process chứa credentials.

Container test được dừng sau nghiệm thu và volume giữ nguyên; Spring HTTP context đóng sau test. Không dừng hoặc sửa container khác.

## Chạy lại và giới hạn

Theo [hướng dẫn runner](../14_HTTP_BASELINE.md), xác minh lại JDK/container/mapping và cấp mật khẩu role test an toàn. Dùng focused mặc định hoặc thêm `-FullSuite`; runner chỉ cộng các XML mới và yêu cầu có report của HttpBaselineTest. Không bật guard thủ công để né preflight.

Fixture không phải bộ tài khoản demo thường trực. Mỗi lượt sinh ID và thời gian tương đối mới, giữ cấu trúc/kỳ vọng tương đương; không có snapshot UUID/thời điểm cố định. Nếu JVM bị kill trước cleanup có thể còn dữ liệu tổng hợp, lượt sau không tự xóa phần dư. Cleanup gặp dữ liệu ngoài tham chiếu sẽ dừng/rollback để người sở hữu kiểm tra.

Không kiểm thử token expiration bằng chờ thời gian, revoke/rotation chưa có trong contract, booking write, concurrency của nghiệp vụ mới, policy/payment/Face/frontend hoặc mọi cách triển khai ngoài Docker Desktop local đã guard. Các quyết định nghiệp vụ/schema còn mở của baseline không được giải quyết hay thay đổi bởi Task A.
