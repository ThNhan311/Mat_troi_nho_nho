# Hiện trạng Backend

Snapshot local: `feature/backend-pt-booking` tại checkpoint source `0ae542abf1eb2796d55e86ddec3095d7dd7ed3fc`, không có upstream. So với ref local `origin/feature/backend-db-alignment` có bốn commit: `dcafe08`, `76c17a4`, `07f006c`, `0ae542a`. Ngày 18/11/2026, `git ls-remote --heads origin` thành công và không thấy nhánh `feature/backend-pt-booking`; nhánh remote `feature/backend-db-alignment` ở `1f3efdd`. Chưa chứng minh bốn commit trên không có trong các nhánh remote khác. Không fetch hay thay đổi refs. Hai worktree database và frontend riêng không mặc nhiên đã tích hợp.

| Phạm vi | Phân loại | Bằng chứng/giới hạn |
|---|---|---|
| Login, refresh, gói, membership, trainer | IMPLEMENTED_AND_TESTED | Controller/service và test hiện hữu; kết quả lịch sử, không chạy lại |
| PT slots, booking của member và PT | IMPLEMENTED_AND_TESTED | Task 04 báo cáo HTTP/DB tại chính HEAD; xem [kiểm thử](06_TESTING_GUIDE.md) |
| Quản lý slot và tạo/hủy/hoàn thành booking | NOT_IMPLEMENTED | Không có controller ghi tương ứng |
| Booking policy | DESIGN_ONLY | Có bảng V4; chưa có API/service |
| Activation, renewal, payment | PARTIALLY_IMPLEMENTED | V2 có bảng; chưa có nghiệp vụ Java đầy đủ |
| Face/check-in, workout, notification, audit | DESIGN_ONLY | Có bảng V3/V5/V6; chưa thấy API Java tương ứng |
| GitHub sau thời điểm kiểm tra, runtime hiện tại | NOT_VERIFIED | Snapshot remote có thể thay đổi; không kết nối DB hay chạy test trong lượt sửa tài liệu |
| PENDING/REJECTED booking | BLOCKED | Xung đột schema V4; cần quyết định nhóm |

`IMPLEMENTED_NOT_TESTED` dùng khi có code nhưng chưa có bằng chứng kiểm thử; không áp đặt cho toàn bộ hành vi của API chỉ vì một số test đã pass. Chi tiết endpoint: [API](05_API_DOCUMENTATION.md).

Trước khi viết tài liệu, Git không báo sửa tracked; có untracked: các báo cáo Task 01–04, `backend/bin/`, backup POM, các startup log, hai SQL demo và một DOCX. Các tệp này không tự động thuộc commit. Xem [vấn đề](09_KNOWN_ISSUES.md) trước khi stage.

## Kế hoạch công bố do người bàn giao tự thực hiện

Nhánh bàn giao dự kiến là `feature/backend-pt-booking`, checkpoint source `0ae542a`; commit tài liệu sẽ có SHA mới sau khi được tạo. Nhánh chưa xuất hiện trên GitHub tại thời điểm kiểm tra; người có quyền cần đối chiếu lại trước công bố. [Tóm tắt Task 04](evidence/TASK04_TEST_SUMMARY.md) nằm trong bộ bàn giao; báo cáo gốc untracked không có trong bản clone trừ khi được chia sẻ riêng sau khi rà soát.

Stage chính xác 18 file trong danh sách dưới sau review; không stage năm script nháp hoặc báo cáo review automation nội bộ. Không stage `backend/bin/`, backup POM, startup logs, SQL demo, DOCX, file môi trường hay báo cáo gốc chưa sanitize. Các commit source đã tồn tại sẽ được push cùng lịch sử branch; stage tài liệu không chọn lọc lại nội dung các commit đó. Đã quét mẫu 52 đường dẫn thay đổi so với `1f3efdd`, có ứng viên trong hai Java test cần review thủ công trước push; quét mẫu không chứng minh không có secrets.

Các file bàn giao hiện là untracked nên `git diff` trước khi stage không hiển thị nội dung của chúng; cần đọc trực tiếp và review `git diff --cached` sau khi stage.

```powershell
git status --short --branch
git rev-parse HEAD
git branch --show-current
git log --oneline 1f3efdd..HEAD
git ls-remote --heads origin feature/backend-pt-booking
$handoverFiles = @(
  'docs/backend-handover/00_START_HERE.md',
  'docs/backend-handover/01_BACKEND_CURRENT_STATUS.md',
  'docs/backend-handover/02_BACKEND_ARCHITECTURE.md',
  'docs/backend-handover/03_LOCAL_SETUP_GUIDE.md',
  'docs/backend-handover/04_DATABASE_GUIDE.md',
  'docs/backend-handover/05_API_DOCUMENTATION.md',
  'docs/backend-handover/06_TESTING_GUIDE.md',
  'docs/backend-handover/07_BUSINESS_RULES_AND_BLOCKERS.md',
  'docs/backend-handover/08_DEVELOPMENT_ROADMAP.md',
  'docs/backend-handover/09_KNOWN_ISSUES.md',
  'docs/backend-handover/10_CODEX_CONTINUATION_PROMPT.md',
  'docs/backend-handover/11_HANDOVER_CHECKLIST.md',
  'docs/backend-handover/12_MANUAL_QUICKSTART.md',
  'docs/backend-handover/13_NEXT_DEVELOPER_TASKS.md',
  'docs/backend-handover/api/openapi.yaml',
  'docs/backend-handover/evidence/TASK04_TEST_SUMMARY.md',
  'docs/backend-handover/evidence/SOURCE_TRACEABILITY.md',
  'docs/backend-handover/scripts/README.md'
)
git add -- $handoverFiles
git diff --cached --name-only
git diff --cached --stat
git diff --cached
# Sau khi tự review và xác nhận remote/branch:
git commit -m "docs: add backend handover"
git push -u origin feature/backend-pt-booking
git rev-parse HEAD
git ls-remote --heads origin feature/backend-pt-booking
```

Các lệnh commit/push chỉ là kế hoạch, chưa thực thi. Trước commit xác nhận staged list chỉ có 18 file đã duyệt; nếu có file khác đã stage từ trước, dừng và xử lý có chủ đích. Trước push review từng commit source và dấu hiệu credential; nếu remote báo không fast-forward, dừng kiểm tra thay vì force push. Sau push so SHA `git rev-parse HEAD` với SHA của `git ls-remote`; chúng phải trùng. Không merge vào main tự động.

Người nhận sau khi branch được công bố dùng `git clone https://github.com/ThNhan311/Mat_troi_nho_nho.git`, `cd Mat_troi_nho_nho`, `git switch --track origin/feature/backend-pt-booking`, `git rev-parse HEAD`; đối chiếu SHA commit tài liệu thực tế. Tạo nhánh công việc riêng bằng `git switch -c feature/<ten-cong-viec>` sau khi nhóm thống nhất baseline.
