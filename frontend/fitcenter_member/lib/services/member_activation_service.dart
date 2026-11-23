import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class MemberActivationService {
  final ApiClient session;
  final http.Client _client;
  final Duration timeout;
  MemberActivationService(
    this.session, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
    int status,
  ) async {
    final epoch = session.sessionEpoch;
    try {
      final r = await _client
          .post(
            session.uri('/auth/member-activation/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (session.sessionEpoch != epoch)
        throw const ApiError(401, 'SESSION_CHANGED', 'Phiên đã thay đổi.');
      Map<String, dynamic> data = {};
      try {
        final d = jsonDecode(r.body);
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
      if (r.statusCode != status) {
        final e = data['error'] is Map ? data['error'] as Map : const {};
        throw ApiError(
          r.statusCode,
          e['code']?.toString() ?? 'HTTP_ERROR',
          e['message']?.toString() ?? 'Yêu cầu không thành công.',
          correlationId:
              e['correlationId']?.toString() ?? r.headers['x-correlation-id'],
          outcomeUnknown: r.statusCode >= 500 && r.statusCode != 503,
        );
      }
      if (data.isEmpty)
        throw const ApiError(
          0,
          'INVALID_RESPONSE',
          'Chưa xác định được kết quả.',
          outcomeUnknown: true,
        );
      return data;
    } on TimeoutException {
      throw const ApiError(
        0,
        'NETWORK_TIMEOUT',
        'Chưa rõ kết quả. Không tự gửi lại; quay về đăng nhập để kiểm tra.',
        outcomeUnknown: true,
      );
    } on http.ClientException {
      throw const ApiError(
        0,
        'NETWORK_ERROR',
        'Mất kết nối. Không tự gửi lại.',
        outcomeUnknown: true,
      );
    }
  }

  Future<void> request(String email) async {
    final r = await _post('request-otp', {'email': email.trim()}, 202);
    if (r['expiresInSeconds'] != 300)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Phản hồi gửi mã không hợp lệ.',
        outcomeUnknown: true,
      );
  }

  Future<String> verify(String email, String otp) async {
    final r = await _post('verify-otp', {
      'email': email.trim(),
      'otp': otp,
    }, 200);
    final grant = r['verificationToken'];
    if (grant is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(grant) ||
        r['expiresInSeconds'] != 300)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Phản hồi xác thực không hợp lệ.',
        outcomeUnknown: true,
      );
    return grant;
  }

  Future<void> password(String grant, String password) async {
    final r = await _post('password', {
      'verificationToken': grant,
      'password': password,
    }, 200);
    if (r['status'] != 'ACTIVE')
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa đối chiếu được kết quả kích hoạt.',
        outcomeUnknown: true,
      );
  }

  void dispose() => _client.close();
}
