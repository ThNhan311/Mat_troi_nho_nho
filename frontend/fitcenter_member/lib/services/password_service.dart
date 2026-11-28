import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Change the signed-in password, or set a new one after an emailed code.
class PasswordService {
  final ApiClient session;
  final http.Client _client;
  final Duration timeout;
  PasswordService(
    this.session, {
    http.Client? client,
    // Sending the mail can take a while.
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
    int status,
  ) async {
    try {
      final response = await _client
          .post(
            session.uri('/auth/password-reset/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      var data = <String, dynamic>{};
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      if (response.statusCode != status) {
        final error = data['error'] is Map ? data['error'] as Map : const {};
        throw ApiError(
          response.statusCode,
          error['code']?.toString() ?? 'HTTP_ERROR',
          error['message']?.toString() ?? 'Yêu cầu không thành công.',
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiError(
        0,
        'NETWORK_TIMEOUT',
        'Hết thời gian chờ. Hãy kiểm tra email trước khi thử lại.',
        outcomeUnknown: true,
      );
    } on http.ClientException {
      throw const ApiError(
        0,
        'NETWORK_ERROR',
        'Không kết nối được máy chủ.',
        outcomeUnknown: true,
      );
    }
  }

  Future<void> requestCode(String email) async {
    await _post('request-otp', {'email': email.trim()}, 202);
  }

  Future<String> verify(String email, String otp) async {
    final data = await _post('verify-otp', {
      'email': email.trim(),
      'otp': otp,
    }, 200);
    final token = data['verificationToken'];
    if (token is! String || token.isEmpty) {
      throw const ApiError(0, 'INVALID_RESPONSE', 'Phản hồi không hợp lệ.');
    }
    return token;
  }

  Future<void> reset(String token, String password) async {
    await _post('password', {
      'verificationToken': token,
      'password': password,
    }, 200);
  }

  Future<void> change(String current, String next) async {
    await session.request(
      'POST',
      '/profile/password',
      body: {'currentPassword': current, 'newPassword': next},
    );
  }
}
