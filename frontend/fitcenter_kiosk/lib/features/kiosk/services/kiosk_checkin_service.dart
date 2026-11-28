import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core_client.dart';
import 'face_service_client.dart';

enum CheckInResult { success, membershipInvalid, noMatch }

class CheckInResponse {
  const CheckInResponse({required this.result, this.memberName});

  final CheckInResult result;
  final String? memberName;
}

class KioskCheckinService {
  KioskCheckinService({FaceServiceClient? client, this.core})
    : _client = client ?? FaceServiceClient();

  final FaceServiceClient _client;
  final CoreClient? core;

  /// Có người đứng trước camera không (Face Service tìm thấy mặt trong ảnh).
  Future<bool> isFacePresent(List<Uint8List> frames) async {
    final result = await _client.identify(frames);
    return result.outcome != FaceOutcome.noFace;
  }

  /// Nhận diện khuôn mặt qua Face Service. Ném [FaceServiceException] khi
  /// service lỗi hoặc không liên lạc được.
  Future<CheckInResponse> checkIn(List<Uint8List> frames) async {
    final result = await _client.identify(frames);
    debugPrint(
      'Face service outcome: ${result.outcome.name} '
      '(${frames.length} frames, ${frames.fold<int>(0, (sum, f) => sum + f.length)} bytes)',
    );

    if (result.outcome != FaceOutcome.success) {
      return const CheckInResponse(result: CheckInResult.noMatch);
    }

    // Face Service chỉ trả mã hội viên; tên và gói tập lấy từ backend.
    final backend = core;
    if (backend == null) {
      return CheckInResponse(
        result: CheckInResult.success,
        memberName: result.memberId,
      );
    }

    final card = await backend.scan(result.memberId!);
    if (card == null) {
      return const CheckInResponse(result: CheckInResult.noMatch);
    }
    return CheckInResponse(
      result: card.membershipValid
          ? CheckInResult.success
          : CheckInResult.membershipInvalid,
      memberName: card.fullName,
    );
  }
}
