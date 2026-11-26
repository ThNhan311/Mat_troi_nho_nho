import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'face_service_config.dart';

/// Yêu cầu đăng ký lễ tân vừa chọn bên web Admin.
class PendingEnrollment {
  const PendingEnrollment({
    required this.requestId,
    required this.memberId,
    required this.memberName,
  });

  final String requestId;
  final String memberId;
  final String memberName;
}

class MemberCard {
  const MemberCard({required this.fullName, required this.membershipValid});

  final String fullName;
  final bool membershipValid;
}

class CoreException implements Exception {
  const CoreException(this.code, [this.statusCode]);

  final String code;
  final int? statusCode;

  @override
  String toString() => 'CoreException($code, $statusCode)';
}

/// Backend FitCenter, chỉ các đường dẫn dành cho kiosk.
class CoreClient {
  CoreClient({
    http.Client? httpClient,
    String? baseUrl,
    String? token,
    this.timeout = const Duration(seconds: 6),
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? FaceServiceConfig.coreApiUrl,
       _token = token ?? FaceServiceConfig.coreKioskToken;

  /// null khi bản build không cấu hình backend: kiosk chạy độc lập như trước.
  static CoreClient? fromEnvironment() =>
      FaceServiceConfig.coreApiUrl.isEmpty ? null : CoreClient();

  final http.Client _http;
  final String _baseUrl;
  final String _token;
  final Duration timeout;

  Future<PendingEnrollment?> pending() async {
    final response = await _send('GET', '/kiosk/enrollment');
    if (response.statusCode == 204) return null;
    final body = _json(response, 200);
    final requestId = body['requestId'];
    final memberId = body['memberId'];
    final name = body['memberName'];
    if (requestId is! String || memberId is! String || name is! String) {
      throw const CoreException('BAD_RESPONSE');
    }
    return PendingEnrollment(
      requestId: requestId,
      memberId: memberId,
      memberName: name,
    );
  }

  /// [outcome] là SUCCESS, DUPLICATE hoặc FAILED.
  Future<void> report(String requestId, String outcome) async {
    final response = await _send(
      'POST',
      '/kiosk/enrollment/${Uri.encodeComponent(requestId)}/result',
      body: {'outcome': outcome},
    );
    if (response.statusCode != 204) {
      throw CoreException('REJECTED', response.statusCode);
    }
  }

  /// Mã các khuôn mặt lễ tân yêu cầu xóa.
  Future<List<String>> removals() async {
    final response = await _send('GET', '/kiosk/removals');
    if (response.statusCode != 200) {
      throw CoreException('REJECTED', response.statusCode);
    }
    try {
      return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
          .cast<String>()
          .toList();
    } catch (_) {
      throw const CoreException('BAD_RESPONSE');
    }
  }

  Future<void> removalDone(String memberId) async {
    final response = await _send(
      'POST',
      '/kiosk/removals/${Uri.encodeComponent(memberId)}/done',
    );
    if (response.statusCode != 204) {
      throw CoreException('REJECTED', response.statusCode);
    }
  }

  /// Báo một lượt nhận diện. null khi mã này không phải hội viên trong hệ thống.
  Future<MemberCard?> scan(String memberId) async {
    final response = await _send(
      'POST',
      '/kiosk/members/${Uri.encodeComponent(memberId)}/scan',
    );
    // 400: mã không phải UUID (đăng ký thử trước đây); 404: không có hội viên.
    if (response.statusCode == 400 || response.statusCode == 404) return null;
    final body = _json(response, 200);
    final name = body['fullName'];
    final valid = body['membershipValid'];
    if (name is! String || valid is! bool) {
      throw const CoreException('BAD_RESPONSE');
    }
    return MemberCard(fullName: name, membershipValid: valid);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['X-Kiosk-Token'] = _token;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const CoreException('TIMEOUT');
    } catch (_) {
      throw const CoreException('NETWORK');
    }
  }

  Map<String, dynamic> _json(http.Response response, int expected) {
    if (response.statusCode != expected) {
      throw CoreException('REJECTED', response.statusCode);
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Xử lý bên dưới.
    }
    throw const CoreException('BAD_RESPONSE');
  }

  void close() => _http.close();
}
