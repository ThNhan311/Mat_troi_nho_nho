# Fixture tổng hợp và HTTP baseline

Harness này kiểm tra các API đã có tại source baseline `8eebb9b` bằng HTTP thật và PostgreSQL test riêng. Không phải E2E toàn hệ thống: không chạy frontend, Face Service, payment provider hoặc API nghiệp vụ mới. Không dùng script onboarding BLOCKED, profile alignment hoặc V7.

## Thành phần

- [Fixture Java](../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineFixture.java): dữ liệu tổng hợp và cleanup giới hạn bằng UUID.
- [HTTP tests](../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/HttpBaselineTest.java): Spring Boot trên cổng loopback ngẫu nhiên, gọi bằng JDK HttpClient, không MockMvc và không endpoint test mới.
- [Runner PowerShell](../../backend/scripts/test-http-baseline.ps1): xác minh tài nguyên trước mọi Spring context/Flyway. Không provision DB hoặc tự thay mật khẩu role.

## Dữ liệu của mỗi lượt

| Bảng | Số dòng | Nội dung |
|---|---:|---|
| users | 5 | ADMIN, MEMBER A/B, PT A/B; ACTIVE; email tổng hợp `@example.invalid` |
| members | 2 | Profile riêng; ID khác users.id, FK về đúng user MEMBER |
| personal_trainers | 2 | Profile riêng; FK về đúng user PT |
| membership_plans | 2 | Một ACTIVE, một INACTIVE để kiểm tra lọc và 404 |
| memberships | 2 | ACTIVE, mỗi member một dòng; ngày nghiệp vụ Asia/Ho_Chi_Minh |
| availability_slots | 6 | PT A: AVAILABLE/BOOKED/DISABLED, gồm slot AVAILABLE quá khứ; PT B: slot riêng |
| bookings | 4 | A: CONFIRMED/CANCELLED/COMPLETED; B: CONFIRMED riêng |

BCrypt được tạo và kiểm tra bằng chính bean PasswordEncoder của ứng dụng. Mật khẩu và JWT chỉ tồn tại trong bộ nhớ; không có tài khoản demo với mật khẩu cố định hoặc file chứa token/hash/password. Actor không có toString chứa credentials; assertions không dump response xác thực.

Slot tương lai được tính từ đầu ngày UTC sau ba ngày, slot quá khứ ở trước ba ngày. Booking dùng đúng bốn cột của FK slot, các khoảng giờ không chồng nhau. CANCELLED do PT có lý do và timestamp; COMPLETED có completed_at. Trạng thái slot trong fixture chỉ là tổ hợp hợp lệ theo schema phục vụ query, không định nghĩa nghiệp vụ chuyển trạng thái sau hủy/hoàn thành. Không seed PENDING/REJECTED, policy hoặc các bảng V3/V5/V6 vì chưa có API trong phạm vi.

Seed là một transaction, commit để các kết nối HTTP nhìn thấy dữ liệu. Mỗi lượt dùng UUID/email/password mới; không upsert, sửa dữ liệu có sẵn hoặc TRUNCATE. AfterAll xóa đúng UUID của instance theo thứ tự FK trong một transaction. Nếu có FK ngoài fixture hoặc notification tham chiếu fixture user, cleanup từ chối và rollback thay vì cascade xóa dữ liệu đó. Một test tạo/dọn fixture thứ hai và so sánh tập ID ở cả bảy bảng để chứng minh fixture thứ nhất không bị xóa. Test khác thêm notification ngoài quyền sở hữu fixture, xác nhận cleanup từ chối, notification vẫn còn và các DELETE trước đó đã rollback.

Nếu JVM bị kill hoặc máy tắt trước AfterAll, có thể còn fixture. Lượt tiếp theo dùng namespace mới và không tự xóa dữ liệu cũ. Cần đối chiếu ID/quan hệ trước khi xử lý phần dư; không DELETE theo prefix/email hàng loạt. Harness không cung cấp dữ liệu đăng nhập demo tồn tại lâu dài.

## Điều kiện trước khi chạy

1. JDK 21 và Maven Wrapper hoạt động. Chỉ đổi JAVA_HOME/PATH trong process chạy test, không cần đổi Java hệ thống.
2. Docker Desktop Linux local; container/volume/port riêng đã xác minh và PostgreSQL 17. Không dùng DB dev, DB alignment, DB Task 04 hoặc DB dùng chung.
3. Database test đã có canonical V1–V6 thành công, không V7. Application role sở hữu schema, có CREATE nhưng không superuser/createdb/createrole/replication/bypassrls.
4. Có mật khẩu application role test; runner hỏi tương tác nếu DB_PASSWORD chưa được cấp an toàn trong process. Không truyền mật khẩu bằng command-line, không ghi vào Git.
5. Không có Spring/Flyway/JVM/Maven overrides ngoài ý muốn. Runner từ chối các override liên quan và kiểm tra riêng target/classes để tránh migration lạ còn sót.

Thiết lập nền: [manual quickstart](12_MANUAL_QUICKSTART.md). Runner không áp schema mới; nếu migration history không đúng V1–V6 thì dừng, không repair/clean. JUnit cũng mở JDBC connection xác minh DB/role/history **trước khi Spring tạo datasource/Flyway**; chỉ chấp nhận URL loopback và tên test rõ ràng.

## Chạy từ repository root trên Windows

Đối chiếu output chỉ chứa identity/mapping, không in toàn bộ docker inspect vì có bootstrap secret:

```powershell
docker --context desktop-linux context inspect desktop-linux --format '{{.Endpoints.docker.Host}}'
docker --context desktop-linux inspect fitcenter-baseline-20261120-db --format '{{.Id}} {{.State.Status}} {{json .Mounts}} {{json .HostConfig.PortBindings}}'
```

Tài nguyên baseline trên máy tiếp nhận: container `fitcenter-baseline-20261120-db`, label `fitcenter.task=baseline-20261120`, volume `fitcenter_baseline_20261120_data`, mapping `127.0.0.1:15437`, database **fitcenter_baseline_20261120_test**, role `fitcenter_baseline_app`. Database dev trong cùng container không phải target của harness.

Sau khi xác minh identity, thay hai placeholder bằng đường dẫn JDK và full container ID đã kiểm tra:

```powershell
$jdk21 = '<absolute-path-to-jdk-21>'
$verifiedContainerId = '<verified-64-character-container-id>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome $jdk21 -ExpectedContainerId $verifiedContainerId -StartDatabase
```

ExecutionPolicy trên lệnh trên chỉ áp cho PowerShell con, không đổi policy máy. Runner hỏi mật khẩu application role bằng SecureString nếu cần. Chỉ dùng mật khẩu của role test đã cấu hình; nếu mất mật khẩu phát triển sinh tạm, người sở hữu môi trường đặt lại qua phiên psql tương tác trên **đúng container test đã xác minh**, không sửa role/database dùng chung.

Mặc định chỉ chạy HttpBaselineTest. Để chạy cả regression và DB/context tests trên cùng target đã xác minh:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/test-http-baseline.ps1 `
  -JavaHome $jdk21 -ExpectedContainerId $verifiedContainerId -StartDatabase -FullSuite
```

Nếu container ban đầu dừng và runner được cấp -StartDatabase, runner chỉ khởi động/dừng đúng container đó; giữ nguyên volume. Nếu container đã chạy, runner để nó chạy. Spring test context được đóng sau suite, không để server HTTP tồn tại. Mọi environment variable runner thay đổi được phục hồi.

Chạy Maven thông thường không bật HTTP harness: RUN_HTTP_BASELINE_TESTS phải true và có guard context của runner mới được chạy. Không dùng dấu guard để bỏ qua preflight. Reports ở backend/target/surefire-reports; runner chỉ cộng XML được ghi mới trong lượt, không cộng các focused/full runs trùng nhau. Khi compilation/preflight lỗi, đọc báo cáo cục bộ và không chia sẻ token/credentials.

## Coverage và giới hạn

- Login thành công cả năm actor; sai mật khẩu/thiếu input; refresh thành công cho ba role; access token không được refresh và refresh token không được dùng làm access token. Không giả định rotation/revocation chưa có trong contract.
- Ma trận ADMIN/MEMBER/PT trên mười đường dẫn GET, cộng kiểm tra ẩn danh. Ca được phép so sánh dữ liệu thay vì chỉ status 200.
- Plan ACTIVE/INACTIVE, membership của cả hai member, trainer catalog/detail, slots/availability alias, PT slots, member/PT bookings.
- So ID, profile ownership, thứ tự, timestamp, trạng thái, trường cancellation/completion, thông tin gói/PT và membership dates. Catalog toàn cục có thể chứa dữ liệu khác: chỉ yêu cầu đúng các fixture rows; query sở hữu yêu cầu danh sách đúng hoàn toàn.
- MEMBER A/B và PT A/B không nhận bookings của nhau, kể cả khi thêm query ID của người khác; PT slots cũng được kiểm tra ownership.
- Bộ lọc ba trạng thái booking/slot, range [from,to), offset +07:00 được URL encode, kết quả rỗng, range/status sai và resource 404.
- Error status, error code, envelope và correlation ID phải hiện diện. Không kiểm thử booking write, policy, payment hay race của nghiệp vụ chưa triển khai.

Runner kiểm tra đúng container ID, label, named volume và port trước khởi động. Không dùng runner này trên tài nguyên dùng chung ngay cả khi đổi được các tham số. Kết quả và working tree cụ thể của lần nghiệm thu: [bằng chứng Task A](evidence/TASK_A_HTTP_BASELINE.md).
