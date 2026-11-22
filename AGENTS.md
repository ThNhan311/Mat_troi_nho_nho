# FitCenter — hướng dẫn tiếp tục

- Đọc [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) và [docs/DECISIONS.md](docs/DECISIONS.md) trước, rồi chỉ mở tài liệu chi tiết liên quan. Xác minh branch/HEAD/status/worktrees; status là snapshot, Git là thực tế.
- Bảo toàn working tree ngoài task, nhất là Face, tài liệu khảo sát và phần công việc chưa commit. Không reset/stash/tự merge/git add .; không commit/push/merge nếu chưa được giao.
- Canonical SQL ở database/migrations, hiện V1–V6. Không sửa migration đã áp; V7 của Duy ở ref database phải được đối chiếu. SQL đề xuất dưới docs không phải migration được phép chạy. Không clean/repair/alignment hoặc onboarding BLOCKED.
- Java dùng JDK21; DB riêng qua backend/scripts/test-http-baseline.ps1 hoặc booking-demo.ps1 với containerID/volume/port/role/history đã xác minh trước Flyway. Không DB dùng chung/LAN/firewall. Cleanup theo đúng UUID; stop đúng tài nguyên tự tạo, giữ volume.
- Giữ UI/theme/navigation gốc. API DTO/UUID/time server, không mock fallback/fake success. Token memory, epoch loại response/modal cũ, không replay write chưa rõ kết quả.
- Không lưu/log password, OTP, token, credential/manifest/raw logs/SDK/cache/build vào Git hoặc docs. Mail chỉ test loopback và địa chỉ tổng hợp khi chưa triển khai adapter production.
- Chạy focused khi sửa, regression phù hợp trước bàn giao; không cộng focused với full hoặc HTTP/DB/UI checks. Evidence phải gắn source hashes. Không gọi kết quả lịch sử là vừa chạy.
- Cập nhật PROJECT_STATUS trước kết thúc; ghi blocker chính xác và phần chưa kiểm chứng. Không tự mở rộng Membership/Payment/Face/Workout.
