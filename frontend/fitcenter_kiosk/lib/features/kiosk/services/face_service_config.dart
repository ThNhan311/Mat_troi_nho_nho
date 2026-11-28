/// Cấu hình Face Service, truyền lúc build/chạy bằng --dart-define.
///
///     flutter run --dart-define=FACE_SERVICE_URL=http://127.0.0.1:8750 \
///       --dart-define=FACE_KIOSK_TOKEN=(giá trị FITCENTER_KIOSK_TOKEN)
///
/// Token kiosk chỉ cho phép nhận diện (/v1/identify) nhưng vẫn nằm trong file
/// build nên có thể bị trích ra. Token Admin KHÔNG được đưa vào đây: Admin nhập
/// lúc đăng ký khuôn mặt. Hợp đồng API: docs/face/API_CONTRACT.md.
class FaceServiceConfig {
  const FaceServiceConfig._();

  static const String baseUrl = String.fromEnvironment(
    'FACE_SERVICE_URL',
    defaultValue: 'http://127.0.0.1:8750',
  );

  static const String kioskToken = String.fromEnvironment('FACE_KIOSK_TOKEN');

  /// Chỉ dùng cho demo trên máy dev: có token này trong bản build thì trang
  /// đăng ký không hỏi mã Admin nữa. Ai có file build đều lấy được token, nên
  /// bản dùng thật KHÔNG đặt biến này (Admin nhập mã trên màn hình).
  static const String adminToken = String.fromEnvironment('FACE_ADMIN_TOKEN');

  static const Duration timeout = Duration(seconds: 8);

  /// Backend FitCenter, ví dụ http://127.0.0.1:18086/api/v1. Để trống thì kiosk
  /// chạy độc lập (không biết khuôn mặt thuộc hội viên nào).
  static const String coreApiUrl = String.fromEnvironment('CORE_API_URL');

  /// Mã bí mật cho đường dẫn kiosk của backend. Chỉ dùng chạy thử trên máy này.
  static const String coreKioskToken = String.fromEnvironment(
    'CORE_KIOSK_TOKEN',
  );
}
