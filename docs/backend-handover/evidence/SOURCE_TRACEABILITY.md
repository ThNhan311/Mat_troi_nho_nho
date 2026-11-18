# Truy vết source và phạm vi kiểm tra

Snapshot local `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`; trạng thái dưới đây là mức đọc/đối chiếu cho từng nhóm, không khẳng định audit đầy đủ từng dòng. Các đường dẫn source tương đối với repository.

| Tài liệu / nhận định | Source và migration | Test / commit | Mức xác minh |
|---|---|---|---|
| 01/05 API và role | `backend/src/main/java/vn/edu/tdtu/fitcenter/controller/`, `config/SecurityConfig.java` | ControllerTest; `76c17a4`, `07f006c`, `0ae542a` | Đọc controller và security; contract chi tiết chưa hoàn tất |
| 02 JWT, danh tính | `security/JwtAuthenticationFilter.java`, `security/JwtService.java`, `service/BookingQueryService.java`, V1/V4 | JwtServiceTest, JwtAuthenticationFilterTest, BookingControllerTest | Đã đối chiếu luồng chính |
| 04 ràng buộc | `database/migrations/V1__core_users_members.sql` đến `V6__audit_log.sql` | `DatabaseAlignmentTest`; [Task 04](TASK04_TEST_SUMMARY.md) | Đọc V1–V6; runtime là lịch sử |
| 04 V7 | `git show fix/database-canonical-layout:database/database/migrations/V7__membership_periods.sql` | branch `558fb03` | Đọc nội dung qua Git; chưa chạy hoặc xác minh dữ liệu |
| 05 DTO | `backend/src/main/java/vn/edu/tdtu/fitcenter/dto/` | Các controller tests | Đã đọc DTO; nullability thực tế cần bổ sung |
| 06 test | `backend/src/test/java/vn/edu/tdtu/fitcenter/` | [Task 04](TASK04_TEST_SUMMARY.md) | Đã kiểm kê và đọc tên/trường hợp; chưa đọc mọi assertion |
| 03 cấu hình | `backend/pom.xml`, `backend/src/main/resources/application*.properties`, `backend/scripts/start-local.ps1` | Task 04 | Đã đọc các phần liên quan; chưa chạy setup |
| 07 nghiệp vụ | Schema comments và source | Chưa xác định SRS/UC/BR chính thức trong checkout | BLOCKED, cần nguồn chính thức |

Chưa đọc đầy đủ từng assertion của tất cả test, toàn bộ seed `demo_data_clean.sql`/`demo_data_review.sql` và mọi dòng báo cáo lịch sử Task 01–04; không sử dụng các seed đó. Không có bằng chứng đã khảo sát đầy đủ SRS/UC/BR, data dictionary hoặc ERD chính thức. Chưa xác nhận nội dung tài liệu trong các worktree khác ngoài V7 qua Git. Không đọc các log có thể chứa credentials.
