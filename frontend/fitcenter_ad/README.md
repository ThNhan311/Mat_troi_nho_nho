# FitCenter Admin Web

Source giao diện: commit0307242, tích hợp authentication và BookingPolicyPage trên theme/Home/navigation gốc. Chỉ Booking Policy nối API; các module còn lại hiển thị Chưa khả dụng.

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1
# Từ repository root:
node frontend/serve-booking-web.mjs ad
```

Mở http://localhost:3002, đăng nhập ADMIN tổng hợp từ manifest local riêng. Session chỉ memory; reload cần login lại. Không đưa credential/token vào source. Flutter3.50.1/Dart3.14.0 đã kiểm chứng; không hạ SDK constraint.

[Quickstart ba app và fixture/cleanup](../../docs/backend-handover/15_BOOKING_WEB_QUICKSTART.md#admin-booking-policy-web), [report/test/evidence](../../docs/backend-handover/evidence/ADMIN_BOOKING_POLICY.md).

GET404 là chưa cấu hình, không có default/fallback. Bốn số nguyên int32 với minima1/0/0/1; effectiveFrom do server đặt. Deadline mới áp cho các yêu cầu Member hủy sau cập nhật, kể cả booking cũ. PUT lỗi mạng/timeout/chưa rõ phải GET đối chiếu trước khi lưu tiếp, không replay mù.