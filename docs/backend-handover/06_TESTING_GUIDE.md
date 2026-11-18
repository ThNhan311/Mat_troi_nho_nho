# Kiểm thử

Không chạy test trong lượt sửa tài liệu. [Task 04](evidence/TASK04_TEST_SUMMARY.md) báo cáo ngày 08/11/2026 tại HEAD `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`: full Maven/JUnit 214 pass, 0 fail/error/skipped; focused Maven 9 pass, không cộng vào full; 90 kiểm tra HTTP ba API, 9 login và 17 kiểm tra SQL pass là các nhóm kiểm tra riêng, không cộng vào số test Maven. Runtime JDK 21.0.11, PostgreSQL 17.11 riêng, Flyway V1–V6, Hibernate validate. Đây là kết quả lịch sử của môi trường báo cáo, không xác nhận môi trường hiện tại.

Riêng quan sát SQLSTATE 23505 của unique index bị SKIPPED vì exclusion constraint chặn trước bằng 23P01; metadata index và việc chặn trùng được báo cáo xác minh, không coi 23505 đã quan sát. HTTP thực dùng fixture tổng hợp, không chứng minh mọi module. BookingRepositoryQueryTest kiểm tra định nghĩa query, không tự chứng minh SQL integration. Unit/Mockito và MockMvc có sẵn dưới [test](../../backend/src/test/).

Trên máy mới trong `backend`, chạy `.\mvnw.cmd test`; mặc định test DB/context có điều kiện có thể bị skip. Muốn bật, tạo DB test độc lập, xác minh URL và quyền, cấu hình `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, đặt `$env:RUN_DB_TESTS='true'`, `$env:JAVA_TOOL_OPTIONS='-Duser.timezone=UTC'` rồi chạy `.\mvnw.cmd test`. Kiểm tra Surefire XML và số skipped thực tế. Build đề xuất `.\mvnw.cmd package` sau khi xác định target; không xem build là test HTTP.

Harness Task 04 được báo cáo lưu ngoài repository trong thư mục tạm của lần chạy cũ; không tìm thấy tại đường dẫn báo cáo khi audit. Chưa thể tái lập đầy đủ 90 HTTP/17 SQL từ source được xác minh; cần xây dựng fixture/harness mới được duyệt, không sao chép token hoặc credentials. Không chạy thử trên DB bảo vệ.

## Danh mục test và lệnh

`AuthServiceTest`, `MembershipServiceTest`, `AvailabilityServiceTest`, `BookingQueryServiceTest`, `PtBookingQueryServiceTest` kiểm thử service; `BookingControllerTest`, `MembershipControllerTest`, `PersonalTrainerControllerTest`, `PtAvailabilityControllerTest`, `PtBookingControllerTest` kiểm thử MVC; `JwtServiceTest`, `JwtAuthenticationFilterTest` kiểm thử bảo mật; `BookingRepositoryQueryTest` kiểm tra định nghĩa repository; `DatabaseAlignmentTest` và `FitcenterApplicationTests` yêu cầu `RUN_DB_TESTS=true`.

Ví dụ focused: `.\mvnw.cmd '-Dtest=BookingControllerTest' test`; full: `.\mvnw.cmd test`. Đọc `backend/target/surefire-reports/TEST-*.xml`, cộng tests/failures/errors/skipped theo suite, không cộng focused vào full. Chỉ gọi HTTP sau khi server thử và fixture riêng đã được xác minh; xem [API](05_API_DOCUMENTATION.md). Tóm tắt có thể chia sẻ: [Task 04](evidence/TASK04_TEST_SUMMARY.md).

## Smoke test nháp

Automation được hoãn; smoke test nháp bị chặn và không thuộc bộ công bố mặc định, xem [trạng thái](scripts/README.md). Người tiếp nhận làm theo [hướng dẫn thủ công](12_MANUAL_QUICKSTART.md), tự xác nhận kết quả trên môi trường riêng. Các lệnh hướng dẫn chưa được kiểm thử đầu-cuối và không thay thế 90 HTTP checks lịch sử của Task 04.
