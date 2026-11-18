# Tóm tắt bằng chứng lịch sử Task 04

Nguồn: báo cáo Task 04 local chưa được theo dõi Git, lập ngày 08/11/2026; báo cáo gốc không có sẵn trong bản clone nếu chưa được chia sẻ riêng. Đây là bản tóm tắt lịch sử, không khẳng định đã chạy lại hoặc độc lập xác minh log. Checkpoint `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`; JDK Temurin 21.0.11, PostgreSQL 17.11 trên DB/role thử riêng, JVM UTC, Flyway V1–V6, Hibernate validate và build JAR được báo cáo thành công.

| Phạm vi | Pass | Fail/error | Skipped |
|---|---:|---:|---:|
| Full Maven, gồm DB/context | 214 | 0/0 | 0 |
| Focused Maven (trùng full; không cộng) | 9 | 0/0 | 0 |
| HTTP ba API | 90 | 0/0 | 0 |
| Login | 9 | 0/0 | 0 |
| Kiểm tra SQL constraint/index | 17 | 0/0 | 0 |

Ba API là GET `/api/v1/pt/slots`, `/api/v1/bookings/me`, `/api/v1/pt/bookings`. Các nhóm kiểm tra gồm login, xác thực/phân quyền, owner, range/status, payload, kết quả rỗng, đối chiếu dữ liệu PostgreSQL và metadata constraints. Bằng chứng đã làm sạch trong báo cáo: FK ghép slot gồm bốn cột, kiểm tra trùng giờ nhận SQLSTATE 23P01, FK sai nhận 23503; profile ID được so với dữ liệu thử. Một kiểm tra SQL riêng nhằm quan sát unique index trả 23505 bị SKIPPED do exclusion constraint chặn trước; không coi 23505 đã được chứng minh. Ca này không nằm trong 17 kiểm tra SQL được báo cáo PASS, và không làm thay đổi số skipped của Maven. Harness gốc không tìm thấy tại vị trí cũ; chưa khôi phục harness hoặc tái lập 90 kiểm tra HTTP.
