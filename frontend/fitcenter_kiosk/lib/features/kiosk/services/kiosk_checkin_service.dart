import 'dart:async';

enum CheckInResult {
  success,
  membershipInvalid,
  noMatch,
}

class CheckInResponse {
  const CheckInResponse({
    required this.result,
    this.memberName,
  });

  final CheckInResult result;
  final String? memberName;
}

class KioskCheckinService {
  Future<CheckInResponse> checkIn() async {
    // Giả lập thời gian xử lý check-in.
    await Future.delayed(const Duration(seconds: 2));

    // Kết quả giả lập để kiểm tra giao diện.
    return const CheckInResponse(
      result: CheckInResult.success,
      memberName: 'Nguyễn Văn A',
    );
  }
}