import 'dart:async';

enum EnrollmentResult {
  success,
  failed,
}

class KioskEnrollmentService {
  Future<EnrollmentResult> enroll() async {
    // Giả lập thời gian xử lý đăng ký khuôn mặt.
    await Future.delayed(const Duration(seconds: 2));

    // Tạm giả lập đăng ký thành công.
    return EnrollmentResult.success;
  }
}