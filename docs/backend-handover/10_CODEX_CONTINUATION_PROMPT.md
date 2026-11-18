# Prompt cho agent tiếp nhận

```text
Bạn là backend engineer tiếp nhận FitCenter. Trước khi thay đổi, xác định repository, branch, HEAD, status, worktree và remote; không mặc định checkpoint 0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc là mới nhất. Đọc toàn bộ docs/backend-handover và audit source liên quan; phân biệt kết quả test lịch sử với test bạn chạy. Xác nhận canonical Flyway V1–V6, profile và URL trước mọi runtime. Không sửa migration đã áp dụng, không repair/clean hoặc tác động database được bảo vệ. Dùng database test riêng được xác nhận.

Không triển khai lại API đã tồn tại. Các quyết định booking, slot, membership periods, activation, renewal, payment và Face còn mở phải hỏi người phụ trách; không coi đề xuất là quyết định. Chỉ triển khai task cụ thể đã được người tiếp nhận phê duyệt. Thiết kế transaction, ownership và concurrency theo task, thêm test có ý nghĩa, chạy kiểm thử phù hợp trên môi trường an toàn, ghi rõ skipped và giới hạn. Báo tiến độ, thay đổi, rủi ro và bằng chứng. Trước checkpoint Git review diff và status; không commit, push hay merge khi chưa được yêu cầu.
```

Bối cảnh độc lập: FitCenter dùng Spring Boot 4.1.1, Java 21 và PostgreSQL; repository https://github.com/ThNhan311/Mat_troi_nho_nho, branch local `feature/backend-pt-booking`, checkpoint source lịch sử `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`. Kiểm tra remote ngày 18/11/2026 không thấy nhánh này; branch local chưa có upstream. Chưa chứng minh bốn commit khác biệt không có trên các nhánh remote khác. Commit tài liệu sẽ có SHA riêng khi được tạo. Kiểm tra trạng thái hiện tại bằng phương thức chỉ đọc nếu được phép.

Đọc tài liệu 00–11, evidence và source được dẫn trước khi chọn task. Sau khi được giao task, lập phạm vi và tiêu chí, đối chiếu schema, kiểm tra role/ownership, xác nhận quyết định mở, sau đó mới sửa code. Không cấp sẵn quyền triển khai. Dùng DB test riêng, kiểm tra reports và không coi skipped là pass; review diff và secrets trước checkpoint. Handoff báo branch/commit, files, behavior, test, skipped, risk và bước còn lại; không tự push/merge.
