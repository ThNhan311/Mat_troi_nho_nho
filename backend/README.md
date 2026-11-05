# FitCenter backend — local development

Backend hiện giữ schema V1–V6. Bản sửa V7/layout và guard bảo vệ lịch sử được chuẩn bị ở nhánh riêng `fix/database-canonical-layout`; chưa áp dụng lên database alignment đang dùng.

## Chạy với PostgreSQL alignment đã có trong Docker

Từ thư mục backend:

```powershell
.\scripts\start-local.ps1 -UseAlignmentContainer
```

Script đọc cấu hình từ container local được chọn (`fitcenter-alignment-db` mặc định), tự xác định port PostgreSQL, không đổi mật khẩu/database và không ghi credentials ra file. Nó chạy profile alignment, HTTP port 8082 và JVM UTC. Các env thay đổi được phục hồi khi script kết thúc.

Nếu chưa có JWT_SECRET, script sinh key development chỉ trong bộ nhớ; token của phiên trước không còn hợp lệ sau khi chạy lại script. Đặt JWT_SECRET ngoài source nếu cần giữ phiên qua lần khởi động. Không dùng key sinh tạm cho production.

Để dùng cấu hình riêng: cấp DB_USERNAME, DB_PASSWORD và JWT_SECRET bằng môi trường rồi chạy:

```powershell
.\scripts\start-local.ps1 -Profile default -DatabaseUrl 'jdbc:postgresql://localhost:5433/fitcenter' -Port 8081
```

Có thể chạy Maven trực tiếp khi đã cấp đủ env:

```powershell
$env:JAVA_TOOL_OPTIONS = '-Duser.timezone=UTC'
.\mvnw.cmd spring-boot:run '-Dspring-boot.run.profiles=alignment'
```

DB_URL ghi đè datasource mặc định; ALIGNMENT_DB_URL ghi đè datasource của profile alignment; SERVER_PORT ghi đè HTTP port.

## Kiểm thử

```powershell
.\mvnw.cmd test
```

Unit/MVC tests không cần PostgreSQL. Hai lớp test context/DB chỉ chạy khi RUN_DB_TESTS=true. Khi bật, dùng database thử riêng đã cấu hình; các test ghi dữ liệu JPA chạy trong transaction rollback.

```powershell
$env:RUN_DB_TESTS = 'true'
# Cấp DB_URL, DB_USERNAME, DB_PASSWORD, JWT_SECRET cho database thử.
.\mvnw.cmd test '-Duser.timezone=UTC'
```

Kết quả đã kiểm chứng: 65/65 backend tests, build JAR thành công; 18/18 kiểm tra HTTP với JWT thật trên fitcenter_verify. Flyway xác nhận V1–V6 khớp và không có migration cần chạy trên database đó.

## Contract và cấu hình frontend

- Danh mục PT: MEMBER. Danh mục gói: MEMBER/ADMIN.
- GET /api/v1/trainers/{ptId}: hồ sơ PT đang ACTIVE.
- GET /api/v1/trainers/{ptId}/slots?from=...&to=...: slot còn trống; /availability tiếp tục được hỗ trợ.
- Khoảng ngày sai trả 400; PT không tồn tại/không ACTIVE trả 404.
- Error envelope có success/error.code/error.message/error.details/error.correlationId/timestamp; status/message ở top level được giữ để tương thích prototype.
- X-Correlation-Id được nhận/trả nếu hợp lệ, hoặc được sinh mới.
- Membership ACTIVE được đối chiếu ngày nghiệp vụ Việt Nam; SUSPENDED/CANCELLED không bị tự kích hoạt lại.
- Flutter Android emulator dùng http://10.0.2.2:8082/api/v1 khi chạy script alignment; web/máy thật dùng địa chỉ phù hợp.
- CORS mặc định cho http://localhost:3000, có thể cấu hình danh sách bằng CORS_ALLOWED_ORIGINS (phân cách dấu phẩy).
