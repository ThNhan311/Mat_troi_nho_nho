# PROMPT GIAO CODEX — FitCenter Face Prototype

> **Cách dùng:** Mở đúng repository `Mat_troi_nho_nho` trong Codex App hoặc VS Code; đặt file `FITCENTER_FACE_PROTOTYPE_SPEC.md` vào workspace hoặc đính kèm cho Codex. Sau đó sao chép toàn bộ phần **PROMPT** dưới đây. Đừng bắt Codex tự merge vào `main`.

---

## PROMPT

Bạn là Senior Python/Computer Vision Engineer kiêm Git Workflow Engineer, đang triển khai prototype Face Recognition Check-in cho FitCenter. Hãy đọc **toàn bộ** file `FITCENTER_FACE_PROTOTYPE_SPEC.md` được cung cấp. Đây là specification điều khiển công việc; đừng âm thầm thay đổi Business Rules.

### 1. Khảo sát repository trước khi sửa
- Chạy `git status`, `git remote -v`, `git branch -a`, `git fetch origin --prune` (nếu có quyền mạng) và kiểm tra thư mục hiện có.
- Xác nhận đúng repo `ThNhan311/Mat_troi_nho_nho`. Nếu sai repo, chưa có quyền, chưa có `.git`, hoặc working tree có thay đổi chưa commit không rõ nguồn gốc: **DỪNG thao tác nguy hiểm và báo cáo**, không reset/stash/xóa thay người dùng.
- Xác định code đang có ở `face/`; không ghi đè bất kỳ công việc nào của đồng đội. Chưa merge các nhánh `backend`, `feature/database-schema`, `frontend`.
- Nếu không thể fetch, chỉ làm với thông tin local và ghi rõ hạn chế; không đoán nhánh.

### 2. Tự tạo nhánh feature mới an toàn
- Nếu working tree sạch, dùng `origin/main` làm base **chỉ cho prototype độc lập** (hoặc base an toàn hơn nếu đã xác nhận và giải thích).
- Tạo nhánh tên `feature/face-prototype-camera-gate`; nếu tên đã tồn tại, không ghi đè; chọn tên hậu tố mới có ý nghĩa và thông báo.
- Không làm việc trên `main`, `backend`, `frontend`, `feature/database-schema`, `old` và không force push/rebase nhánh của người khác.
- Trước khi coding, in ra: branch nguồn, branch mới, đường dẫn sẽ thêm/sửa, rủi ro và kế hoạch triển khai ngắn.

### 3. Thực hiện MVP theo specification
Tạo module độc lập dưới `face/` (điều chỉnh bố cục nếu repo có tổ chức khác, giải thích rõ):
1. `CameraCapture`: preview webcam cục bộ, xử lý reconnect/error/shutdown, không tự ghi ảnh.
2. `FaceDetector` adapter: ưu tiên MediaPipe API tương thích với phiên bản thực tế, trả các bounding boxes; cho phép mock detector.
3. `EligibleFaceSelector`: `SizeOK AND QualityOK AND InsideROI`, ngưỡng và ROI configurable, lý do reject, 0/1/>=2 eligible; không đếm những mặt bé ở background như khuôn mặt đủ điều kiện.
4. `StableFaceGate`: chống kích hoạt do khuôn mặt chập chờn; chỉ READY khi đúng 1 mặt đủ điều kiện đủ ổn định.
5. `AuthStateMachine`: `IDLE -> READY -> VERIFYING -> COOLDOWN -> IDLE`, single-flight request, timeout, no re-entrant call, ignore stale request_id, re-arm after face leaves ROI following success.
6. `MockAuthClient`: mô phỏng SUCCESS/REJECTED/TIMEOUT/ERROR để kiểm chứng luồng, **không giả vờ là xác thực sinh trắc học thật**.
7. UI/demo hiển thị ROI, eligible faces, trạng thái hiện tại và hướng dẫn khi 0 hoặc >=2 faces. Preview phải không bị block bởi network worker.
8. Cấu hình ban đầu: detection 5–10Hz, stable 0.5–1s, timeout 5–10s, cooldown 5s, tối đa 1 request đang xử lý. 30 phút là quy tắc Attendance sau tích hợp, không dùng thay cooldown.
9. Viết tests pytest cho tất cả test cases T01–T16 phù hợp phạm vi, mock camera/network để chạy headless.
10. README Windows PowerShell và báo cáo `docs/face/PROTOTYPE_TEST_REPORT.md` chỉ ghi những gì thực sự chạy/đo được; nêu rõ skipped/blocked, không bịa PASS.

### 4. Kiểm soát quyền và chất lượng
- Được phép tạo/sửa file mới trong nhánh feature, tạo virtualenv cục bộ, cài dependency cần thiết và chạy kiểm thử nếu được môi trường cho phép.
- Không tự thay Spring Boot/database migrations/Flutter, không dùng ảnh hội viên thật, không upload biometrics, không tạo secret, không mở access control thật.
- Không tự pull làm ghi đè working tree, không xóa branch, không reset hard, không sửa dữ liệu production, không thay đổi GitHub settings.
- Chỉ commit các file thuộc task sau khi review `git diff` và tất cả test phù hợp đã chạy; nếu test thất bại, khắc phục hoặc báo cáo blocker, không ghi là hoàn tất.
- **Được tạo commit ở nhánh riêng khi hoàn tất.** Trước khi `git push` hoặc mở PR, yêu cầu tôi duyệt diff và kết quả test; **tuyệt đối không merge**. Nếu tôi đồng ý ở lượt sau, push branch đó và tạo draft PR, base `main` hoặc nhánh tích hợp được nhóm chốt.
- Không làm những thao tác phá hủy hoặc vượt quyền một cách tự động.

### 5. Báo cáo cuối cùng bằng tiếng Việt
- Repo/branch/commit, các file được tạo/sửa, cách chạy demo/test trên Windows.
- Bảng T01–T16 với PASS/FAIL/SKIPPED cùng bằng chứng từ test runner, không suy đoán.
- Các hạn chế phần cứng/camera/model và phần chưa làm (real liveness, real recognition, Spring Boot integration).
- Đề xuất prompt ở giai đoạn 2, sau khi MVP được kiểm thử và duyệt.

**Bắt đầu bằng khảo sát Git + kế hoạch, sau đó thực thi trên nhánh mới nếu đáp ứng các điều kiện an toàn; không chỉ trả lời lý thuyết.**

---

## Prompt ngắn dùng sau khi đã review diff và muốn push/PR

Tôi đã review diff và kết quả test trên nhánh feature Face Prototype. Hãy kiểm tra lại `git status`, `git diff`, `git log -1`, xác nhận không có secret, ảnh sinh trắc học hay thay đổi ngoài phạm vi. Nếu tất cả đạt, `git push -u origin <current-feature-branch>` rồi tạo **draft Pull Request** vào nhánh đích phù hợp. Không merge, không auto-merge, không thay đổi branch protection. Báo URL PR và các check hiện có.
