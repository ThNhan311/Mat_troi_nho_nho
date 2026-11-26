import 'dart:async';

import 'package:flutter/foundation.dart';

import 'face_service_client.dart';

enum EnrollmentResult {
  success,
  failed,

  /// Khuôn mặt này đã được đăng ký cho một hội viên khác (hoặc chính người này).
  duplicate,
}

class KioskEnrollmentService {
  KioskEnrollmentService({FaceServiceClient? client})
    : _client = client ?? FaceServiceClient();

  final FaceServiceClient _client;

  /// Đăng ký khuôn mặt cho [memberId]. Chỉ Admin có [adminToken]; token không
  /// được lưu lại. Khuôn mặt đã đăng ký trả [EnrollmentResult.duplicate]; mọi
  /// lỗi khác (thiếu mặt, sai token, mất kết nối) trả [EnrollmentResult.failed].
  Future<EnrollmentResult> enroll({
    required String memberId,
    required String adminToken,
    required List<Uint8List> frames,
  }) async {
    try {
      await _client.enroll(
        memberId: memberId,
        adminToken: adminToken,
        frames: frames,
      );
      return EnrollmentResult.success;
    } on FaceServiceException catch (error) {
      debugPrint('Enrollment failed: $error');
      if (error.code == 'DUPLICATE_IDENTITY') {
        return EnrollmentResult.duplicate;
      }
      return EnrollmentResult.failed;
    }
  }
}
