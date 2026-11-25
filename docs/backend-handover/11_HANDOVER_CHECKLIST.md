# Checklist người tiếp nhận

Người tiếp nhận tự đánh dấu sau khi xác minh:

- [ ] Có quyền GitHub, clone được repository và checkout đúng branch đã công bố.
- [ ] Xác minh commit với người bàn giao và kiểm tra Git status.
- [ ] JDK 21 và Maven Wrapper hoạt động.
- [ ] Docker/PostgreSQL hoạt động; database phát triển và test riêng đã thiết lập.
- [ ] Xác minh URL/profile; Flyway V1–V6 migrate thành công trên DB riêng.
- [ ] Backend khởi động, fixture an toàn được duyệt, login và gọi API hiện có thành công.
- [ ] Chạy test phù hợp, ghi lại kết quả và skipped.
- [ ] Hiểu cấu trúc source, danh tính user/member/PT và ownership.
- [ ] Hiểu các nghiệp vụ còn mở, rủi ro V7 và lịch sử payment.
- [ ] Thống nhất task tiếp theo và cách liên hệ Nhân, Duy, người phụ trách database/nghiệp vụ.

## Người bàn giao

- [ ] Rà soát secrets, evidence và tính khả dụng của các liên kết sau clone.
- [ ] Xác nhận checkpoint source `0ae542a`, commit tài liệu sau khi tạo, nhánh, quyền và công bố theo kế hoạch đã duyệt. Ngày 18/11/2026 chưa thấy nhánh trên remote và local chưa có upstream.
- [ ] Chuyển giao danh sách blocker và đầu mối.

## Database và API

- [ ] Xác nhận target DB riêng, role ứng dụng, migration và tránh alignment.
- [ ] Xác minh login MEMBER/PT/ADMIN bằng fixture tổng hợp an toàn.
- [ ] Xác minh quyền, ownership, lọc thời gian/status và lỗi API trên DB riêng.
- [ ] Thống nhất task tiếp theo, tiêu chí nghiệm thu và người duyệt.
- [ ] Thực hiện [setup thủ công](12_MANUAL_QUICKSTART.md) trên máy và database riêng; ghi lại kết quả runtime, các bước còn thiếu và skipped.
- [ ] Thống nhất [việc tiếp theo](13_NEXT_DEVELOPER_TASKS.md); automation nháp được hoãn và không dùng cho onboarding.
