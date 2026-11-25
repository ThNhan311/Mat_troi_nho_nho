# FitCenter member — Booking Web

Source Frontend0307242, Backend base089b5e2. [main](lib/main.dart) mở form Login, Home/navigation và các màn hình gốc đã nối API thật; dashboard cũ chỉ giữ cho regression, không là entry chính.

[Quickstart đầy đủ](../../docs/backend-handover/15_BOOKING_WEB_QUICKSTART.md), [kết quả kiểm chứng](../../docs/backend-handover/evidence/BOOKING_WEB_INTEGRATION.md).

Dùng Flutter3.50.1/Dart3.14.0, giữ pubspec constraints. Từ project:

~~~powershell
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:18081/api/v1
~~~

Từ repository root chạy node frontend/serve-booking-web.mjs member, mở http://localhost:3000. Chuẩn bị Backend/DB/fixture theo quickstart. Không credential/token mặc định; session chỉ memory, reload cần login lại. Không replay POST khi lỗi mạng/kết quả chưa rõ; tải lại lịch/slot để đối chiếu trước thao tác mới.

Lifecycle đã nối: hủy booking có xác nhận, deadline do server. [Báo cáo lifecycle](../../docs/backend-handover/evidence/BOOKING_WEB_LIFECYCLE.md). Không replay write khi lỗi mạng; kết quả eligibility không ghi nhận bắt đầu.

[Thiết kế gốc và kiểm chứng hiện tại](../../docs/backend-handover/evidence/ORIGINAL_UI_INTEGRATION.md). Các module chưa có API hiển thị Chưa khả dụng.
