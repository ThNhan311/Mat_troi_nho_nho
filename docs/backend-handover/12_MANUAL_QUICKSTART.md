# Thiết lập Backend thủ công trên Windows

**Đây là hướng dẫn đề xuất, chưa được chạy đầu-cuối.** Các lệnh dưới đây được viết từ source tại checkpoint `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`; người tiếp nhận cần tự xác minh trên môi trường riêng. Không dùng năm script nháp, profile `alignment`, database `fitcenter_verify` hoặc database Task 04. Không chạy Flyway repair/clean, reset database hay xóa volume để xử lý lỗi.

[Task 04](evidence/TASK04_TEST_SUMMARY.md) là bằng chứng lịch sử: JDK 21.0.11, PostgreSQL 17.11, database/role thử riêng, Flyway V1–V6, Hibernate validate, Maven và HTTP đã được báo cáo thành công. Báo cáo **không chứng minh các lệnh mới trong hướng dẫn này đã được thực thi**.

## 1. Clone và xác nhận source

Mục đích: lấy nhánh sau khi người bàn giao công bố; ngày 18/11/2026 GitHub chưa có nhánh này. Cần quyền repository trước khi chạy:

```powershell
git clone https://github.com/ThNhan311/Mat_troi_nho_nho.git
cd Mat_troi_nho_nho
git switch --track origin/feature/backend-pt-booking
git status --short --branch
git rev-parse HEAD
git log -5 --oneline
```

Mong đợi nhánh đúng, working tree sạch và SHA khớp SHA bàn giao mới. `0ae542a` là checkpoint source lịch sử; commit tài liệu mới sẽ có SHA khác. Nếu checkout báo không tìm thấy remote branch, liên hệ người bàn giao; không tự chuyển sang nhánh khác rồi coi là đúng.

## 2. JDK, Maven Wrapper và Docker

Mục đích: chuẩn bị JDK 21 và công cụ, không yêu cầu đường dẫn máy người bàn giao:

```powershell
java -version
Test-Path "$env:JAVA_HOME\bin\java.exe"
cd backend
.\mvnw.cmd -version
docker version
cd ..
```

Mong đợi `java -version` và Maven Wrapper cùng báo Java 21, Docker client/server hoạt động. Nếu Maven báo JDK khác, đặt `JAVA_HOME` theo JDK 21 trên máy và đưa `JAVA_HOME\bin` lên `PATH` trong terminal; chạy lại các kiểm tra. Wrapper có thể cần mạng để tải Maven/dependency; nếu không tải được, kiểm tra kết nối và quyền truy cập.

## 3. Chọn tài nguyên database riêng

Ví dụ dự kiến dùng container `fitcenter-manual-dev-db`, volume `fitcenter_manual_dev_data`, DB `fitcenter_manual_dev`, role `fitcenter_manual_app`, port `15436`. Không dùng các tên này nếu đã tồn tại; chọn tên/port khác và thay **nhất quán** ở các lệnh sau. Kiểm tra:

```powershell
docker ps -a --filter 'name=^/fitcenter-manual-dev-db$'
docker volume ls --filter 'name=^fitcenter_manual_dev_data$'
Get-NetTCPConnection -LocalPort 15436 -ErrorAction SilentlyContinue
```

Mong đợi không có container, volume hoặc listener tương ứng. Nếu có, dừng và chọn tên/port mới; không xóa hoặc ghi đè tài nguyên đang tồn tại. Xác nhận Docker context là máy phát triển được phép bằng `docker context show` và `docker context inspect`; nếu không chắc target, dừng.

## 4. Tạo PostgreSQL 17 và role riêng

Mục đích: bootstrap một database mới, không dùng bootstrap superuser làm role ứng dụng. Nhập một mật khẩu bootstrap tổng hợp mới tương tác; đoạn này chỉ giữ giá trị trong process, không đưa literal vào lịch sử lệnh:

```powershell
$bootstrapSecure = Read-Host 'Mật khẩu bootstrap mới' -AsSecureString
$bootstrapPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($bootstrapSecure)
try { $env:POSTGRES_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bootstrapPtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bootstrapPtr) }
docker volume create fitcenter_manual_dev_data
docker run -d --name fitcenter-manual-dev-db -e POSTGRES_USER=fitcenter_manual_admin -e POSTGRES_PASSWORD -e POSTGRES_DB=postgres -p 127.0.0.1:15436:5432 -v fitcenter_manual_dev_data:/var/lib/postgresql/data postgres:17
Remove-Item Env:POSTGRES_PASSWORD
```

Mong đợi hai lệnh Docker thành công. Docker có thể tải image; nếu không có image hoặc quyền, dừng và kiểm tra trước khi thử lại. Bootstrap password nằm trong cấu hình container, người có quyền Docker có thể đọc: chỉ dùng secret phát triển mới, không dùng mật khẩu cá nhân. Nếu lỗi giữa chừng, kiểm tra chính xác tài nguyên đã tạo; không tự xóa hoặc chạy lại trên volume đã tồn tại.

Chờ sẵn sàng, rồi tạo role và database, với các lệnh sau **chỉ áp dụng đúng container vừa tạo**:

```powershell
docker exec fitcenter-manual-dev-db pg_isready -h 127.0.0.1 -U fitcenter_manual_admin -d postgres
docker exec fitcenter-manual-dev-db psql -X -v ON_ERROR_STOP=1 -U fitcenter_manual_admin -d postgres -c 'CREATE ROLE fitcenter_manual_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE'
docker exec fitcenter-manual-dev-db createdb -U fitcenter_manual_admin -O fitcenter_manual_app fitcenter_manual_dev
docker exec fitcenter-manual-dev-db psql -X -v ON_ERROR_STOP=1 -U fitcenter_manual_admin -d fitcenter_manual_dev -c 'CREATE EXTENSION IF NOT EXISTS btree_gist'
docker exec -it fitcenter-manual-dev-db psql -X -U fitcenter_manual_admin -d postgres
```

Trong `psql`, đặt mật khẩu application role **khác** mật khẩu bootstrap bằng lệnh tương tác sau, nhập mật khẩu tổng hợp mới khi được hỏi rồi thoát:

```text
\password fitcenter_manual_app
\q
```

`pg_isready` cần báo accepting connections; nếu chưa, chờ rồi kiểm tra lại. Nếu role/database đã tồn tại hoặc lệnh báo lỗi, dừng và đối chiếu container, không ghi đè. `-it` cần terminal hỗ trợ TTY. Extension `btree_gist` được V1 yêu cầu; quyền owner/schema cần được xác minh trên DB mới, không tự cấp superuser cho application role.

## 5. Xác minh target và cấu hình process

Mục đích: bảo đảm ứng dụng kết nối đúng DB/role mới. Nhập lại mật khẩu application trong terminal hiện tại, không dán literal vào lệnh:

```powershell
$appSecure = Read-Host 'Mật khẩu application role' -AsSecureString
$appPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecure)
try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($appPtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($appPtr) }
docker exec -e PGPASSWORD fitcenter-manual-dev-db psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U fitcenter_manual_app -d fitcenter_manual_dev -c 'SELECT current_database(), current_user;'
docker exec fitcenter-manual-dev-db psql -X -U fitcenter_manual_admin -d postgres -c "SELECT rolname, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname = 'fitcenter_manual_app';"
```

Mong đợi `fitcenter_manual_dev`, `fitcenter_manual_app` và cả ba cờ quyền là false. Kiểm tra thêm `docker inspect fitcenter-manual-dev-db` và mapping `127.0.0.1:15436` bằng `docker port fitcenter-manual-dev-db`; **không chia sẻ output inspect vì có thể chứa mật khẩu bootstrap**. Dừng nếu container/volume/mapping khác dự kiến hoặc query thất bại. Tên database/role riêng tự nó không chứng minh server đúng; phải đối chiếu cả container, volume, port và kết nối.

Trong cùng terminal, cấp cấu hình cho Backend:

```powershell
$env:DB_URL = 'jdbc:postgresql://127.0.0.1:15436/fitcenter_manual_dev'
$env:DB_USERNAME = 'fitcenter_manual_app'
$env:DB_PASSWORD = $env:PGPASSWORD
$env:SERVER_PORT = '18081'
$env:JAVA_TOOL_OPTIONS = '-Duser.timezone=UTC'
$jwtSecure = Read-Host 'JWT secret mới, ít nhất 32 byte UTF-8' -AsSecureString
$jwtPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($jwtSecure)
try { $env:JWT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($jwtPtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($jwtPtr) }
Remove-Item Env:PGPASSWORD
```

Kiểm tra độ dài bằng `[Text.Encoding]::UTF8.GetByteCount($env:JWT_SECRET)` mà không in secret; cần ít nhất 32 byte. Không đặt profile `alignment`, `SPRING_DATASOURCE_URL`, `SPRING_APPLICATION_JSON` hoặc `FLYWAY_LOCATIONS` trỏ nơi khác; kiểm tra các override hiện có trước khi chạy. Biến process không tự chuyển sang terminal khác: nhập lại an toàn trong terminal test, không sao chép mật khẩu/JWT vào file.

## 6. Khởi động và kiểm tra migration

Mục đích: Flyway tự migrate canonical V1–V6 khi ứng dụng khởi động, sau đó Hibernate validate. Sau khi xác minh DB riêng và port 18081 còn trống:

```powershell
Get-NetTCPConnection -LocalPort 18081 -ErrorAction SilentlyContinue
Get-ChildItem database/migrations/V*__*.sql | Select-Object Name
cd backend
.\mvnw.cmd spring-boot:run '-Dspring-boot.run.arguments=--server.address=127.0.0.1'
```

Mong đợi chỉ V1–V6 trong canonical folder, log Flyway migrate/validate thành công, Hibernate không báo sai schema và ứng dụng lắng nghe loopback 18081. POM đóng gói canonical migrations vào classpath, loại migrations legacy. Nếu lỗi quyền extension, migration checksum hoặc schema, dừng và xác nhận target, quyền và migration history với người phụ trách; không tự repair/clean. Log `BUILD SUCCESS` không chứng minh HTTP readiness. Đây là lệnh đề xuất chưa được chạy trong lượt bàn giao.

## 7. Dữ liệu tổng hợp và login

**Chưa có fixture/tài khoản demo được thẩm định.** Người tiếp nhận cần phối hợp người phụ trách để tạo dữ liệu tổng hợp trên DB riêng: `users` ACTIVE với email tổng hợp và BCrypt hash; với MEMBER/PT phải có profile tương ứng qua `user_id`. Không sao chép SQL demo cá nhân, payment history, credentials hoặc token thật. Schema tham chiếu [V1](../../database/migrations/V1__core_users_members.sql) và [V2](../../database/migrations/V2__membership_payment.sql). Không có lệnh seed hoàn chỉnh được xác nhận trong bộ này.

Backend dùng `BCryptPasswordEncoder` mặc định trong [SecurityConfig](../../backend/src/main/java/vn/edu/tdtu/fitcenter/config/SecurityConfig.java). Tạo hash từ mật khẩu tổng hợp bằng công cụ BCrypt tương thích được nhóm phê duyệt; xác minh bằng `matches` của chính Spring Security trước khi nạp. Chưa có lệnh tạo hash độc lập được kiểm chứng ở đây; nhờ người phụ trách hỗ trợ, không dùng hash giả hoặc bỏ chốt script nháp.

Sau khi fixture đã được duyệt và nạp vào DB riêng, ở terminal thứ hai nhập mật khẩu demo tương tác, rồi gửi login:

```powershell
$demoSecure = Read-Host 'Mật khẩu tài khoản demo tổng hợp' -AsSecureString
$demoPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($demoSecure)
try { $demoPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($demoPtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($demoPtr) }
$body = @{ email = 'member@example.invalid'; password = $demoPassword } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18081/api/v1/auth/login' -ContentType 'application/json' -Body $body
$headers = @{ Authorization = "Bearer $($login.accessToken)" }
Invoke-RestMethod -Headers $headers -Uri 'http://127.0.0.1:18081/api/v1/memberships/me'
```

Thay email bằng email tổng hợp **đã tạo**; mong đợi login 200 và role MEMBER, API trả mảng membership có thể rỗng. Không in `$login`, `$body` hay token; xóa các biến nhạy cảm khỏi terminal khi xong. Nếu 401, kiểm tra user ACTIVE, BCrypt và đúng target; 403 thường là sai role. Postman có thể gửi cùng JSON và Bearer token đến URL loopback, không chia sẻ collection chứa secrets. Xem [API](05_API_DOCUMENTATION.md) về role và tham số.

## 8. Test và dừng an toàn

Mục đích: kiểm thử trên môi trường đã chuẩn bị. Từ terminal riêng, cấp lại `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET` an toàn và xác nhận target; từ `backend`:

```powershell
.\mvnw.cmd test
```

Mặc định một số test DB/context có thể skipped. Chỉ đặt `$env:RUN_DB_TESTS='true'` sau khi thiết lập và xác minh **database test riêng** có thể ghi, không dùng DB bảo vệ; xem [testing](06_TESTING_GUIDE.md) và Surefire reports để đếm pass/fail/error/skipped. Nếu test lỗi, đọc báo cáo và kiểm tra cấu hình, không giả định pass.

Ctrl+C trong terminal backend để dừng tiến trình; xác nhận port 18081 không còn listener. Chỉ khi đã xác định đúng container do mình tạo, có thể dùng `docker stop fitcenter-manual-dev-db`; không xóa volume. Các bước ở đây chưa được thử đầu-cuối.
