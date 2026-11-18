# Thiết lập Windows: bản chuẩn bị, chưa được chạy thử

**Hướng dẫn bàn giao đề xuất:** xem [manual quickstart](12_MANUAL_QUICKSTART.md). Các bước chưa được kiểm thử đầu-cuối; người nhận cần tự xác nhận trên máy riêng. Automation được hoãn, các script nháp không thuộc bộ công bố mặc định; xem [trạng thái](scripts/README.md). Không chạy trên database hiện có hoặc profile `alignment`. Flyway tự chạy khi Spring Boot khởi động.

Các script nháp nội bộ vẫn BLOCKED và không được bỏ chốt chặn. Không dùng chúng để onboarding.

## Lấy source và công cụ

Sau khi được cấp quyền và nhánh đã công bố:

```powershell
git clone https://github.com/ThNhan311/Mat_troi_nho_nho.git
cd Mat_troi_nho_nho
git switch --track origin/feature/backend-pt-booking
git rev-parse HEAD
java -version
docker version
cd backend
.\mvnw.cmd -version
```

Kỳ vọng Java 21, Docker client/server sẵn sàng; đối chiếu HEAD với SHA bàn giao mới. Checkpoint source local là `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`; commit tài liệu sẽ có SHA khác sau khi tạo. `ls-remote` ngày 18/11/2026 chưa thấy nhánh này trên GitHub, branch local chưa có upstream; chưa chứng minh bốn commit khác biệt không nằm trên các branch remote khác. Liên hệ người bàn giao nếu nhánh chưa được công bố. Nếu Java sai, cài JDK 21 theo hướng dẫn nhà cung cấp và đặt `JAVA_HOME` theo máy của bạn. Maven Wrapper cần mạng và thư viện phù hợp.

## Database và vai trò

Trước khi tạo môi trường, chọn tên container/volume/database và cổng loopback mới; kiểm tra `docker ps -a`, `docker volume ls` và `Get-NetTCPConnection -LocalPort <port> -ErrorAction SilentlyContinue`. Dừng khi tên hoặc port đã dùng. Không xóa hay ghi đè tài nguyên. Cần PostgreSQL 17 với bootstrap administrator và role ứng dụng riêng, không superuser. Tạo database dev riêng do role ứng dụng sở hữu; chuẩn bị extension `btree_gist` bằng bootstrap role nếu cần, sau đó cho role ứng dụng quyền sở hữu schema và quyền cần thiết để Flyway tạo bảng, trigger và functions. Chính xác grants và thứ tự phải được thử trên DB trống riêng trước khi đưa thành lệnh onboarding; chưa có script setup được xác minh. Không dùng user `POSTGRES_USER` bootstrap làm mặc định ứng dụng.

Quy trình thủ công đề xuất tên và port riêng trong [manual quickstart](12_MANUAL_QUICKSTART.md); trước mỗi thao tác cần xác minh target và collision. Docker có thể lưu bootstrap password trong cấu hình container; chỉ dùng secret tổng hợp, không dùng mật khẩu cá nhân.

Chờ PostgreSQL sẵn sàng bằng `pg_isready` trên container mới, rồi bằng phiên SQL đã xác định đích kiểm tra `SELECT current_database(), current_user;`. Dừng nếu khác database và role đã chọn. Không chép mật khẩu, hash hay JWT thực vào file, lệnh shell có lịch sử, log hoặc báo cáo. Nhập bí mật tương tác/secret manager phù hợp và đặt environment variables process-scope `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`; JWT cần ít nhất 32 byte UTF-8. Đặt `SERVER_PORT` chưa dùng, `JAVA_TOOL_OPTIONS=-Duser.timezone=UTC`; không kích hoạt profile alignment. Với terminal test khác, biến process không tự kế thừa: cấp lại secrets an toàn trong terminal đó và xác minh lại URL.

## Chạy và kiểm thử sau phê duyệt

Sau khi đối chiếu DB riêng, source và resource V1–V6, chạy `.\mvnw.cmd spring-boot:run` từ `backend`. Kiểm tra log Flyway áp V1–V6 và Hibernate validate, không lộ secret; nếu lỗi extension/quyền, dừng và sửa quyền trên DB riêng sau khi xác minh, không chạy repair/clean. Không có endpoint health được xác định; chỉ kết luận hoạt động sau khi login và API trả kết quả đúng.

Chưa có fixture tổng hợp được thẩm định để cấp tài khoản MEMBER/PT/ADMIN. Không sử dụng các SQL demo cá nhân chưa được thẩm định. Chuẩn bị fixture mới với BCrypt hash được tạo từ secret riêng và kiểm tra constraints trước khi chạy. Đăng nhập qua POST `/api/v1/auth/login` với JSON `email,password`, giữ access token trong bộ nhớ, rồi gọi API theo [API](05_API_DOCUMENTATION.md). Chưa thể cung cấp thông tin đăng nhập đã kiểm chứng. Chạy `.\mvnw.cmd test` theo [kiểm thử](06_TESTING_GUIDE.md); kiểm tra skipped. Dừng process backend bằng Ctrl+C; chỉ dừng container do chính bạn tạo sau khi xác nhận tên. Không xóa volume.

## Hướng dẫn tiếp nhận

Dùng [manual quickstart](12_MANUAL_QUICKSTART.md) để chuẩn bị môi trường riêng và phối hợp tạo fixture. Các lệnh hướng dẫn mới chưa được chạy đầu-cuối; không có tài khoản demo được chứng minh sẵn. Người nhận ghi kết quả của mình vào [checklist](11_HANDOVER_CHECKLIST.md). Không dùng fixture trên môi trường đang bảo vệ.
