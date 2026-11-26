import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_store.dart';

class ApiError implements Exception {
  final int status;
  final String code, message;
  final String? correlationId;
  final bool outcomeUnknown;
  const ApiError(
    this.status,
    this.code,
    this.message, {
    this.correlationId,
    this.outcomeUnknown = false,
  });
  @override
  String toString() =>
      '$message [$code]${correlationId == null ? '' : ' • Mã đối chiếu: ${correlationId!}'}';
}

/// Tokens exist only in this instance unless an optional [SessionStore] is
/// given (local testing only). No dumps or automatic write replay.
class ApiClient extends ChangeNotifier {
  final SessionStore? _store;
  static const configuredUrl = String.fromEnvironment('API_BASE_URL');
  final String expectedRole;
  final Uri? baseUri;
  final http.Client _http;
  final Duration timeout;
  String? _access, _refresh;
  Future<void>? _refreshing;
  int _generation = 0;
  bool get authenticated => _access != null;
  int get sessionEpoch => _generation;

  ApiClient({
    required this.expectedRole,
    Uri? baseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    SessionStore? store,
  }) : baseUri = baseUri ?? Uri.tryParse(configuredUrl),
       _http = client ?? http.Client(),
       _store = store {
    _restore();
  }

  void _restore() {
    final saved = _store?.read();
    if (saved == null) return;
    try {
      // Same role and token checks as a server response.
      _acceptTokens(jsonDecode(saved), _generation);
    } on FormatException {
      _store?.clear();
    } on ApiError {
      _store?.clear();
    }
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final base = baseUri;
    if (base == null ||
        !['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const ApiError(
        0,
        'CONFIGURATION',
        'Cần cấu hình API_BASE_URL qua dart-define.',
      );
    }
    return base.replace(
      path: base.path.replaceFirst(RegExp(r'/$'), '') + path,
      queryParameters: query,
    );
  }

  void logout() {
    _generation++;
    _refreshing = null;
    _access = null;
    _refresh = null;
    _store?.clear();
    notifyListeners();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    try {
      return await (() async => http.Response.fromStream(
        await _http.send(request),
      ))().timeout(timeout);
    } on TimeoutException {
      throw ApiError(
        0,
        'NETWORK_TIMEOUT',
        method == 'GET' ? 'Hết thời gian tải dữ liệu. Hãy tải lại.' : 'Chưa rõ kết quả gửi. Không gửi lại ngay; hãy tải lại dữ liệu để đối chiếu.',
        outcomeUnknown: method != 'GET',
      );
    } on http.ClientException {
      throw ApiError(
        0,
        'NETWORK_ERROR',
        method == 'GET' ? 'Không kết nối được máy chủ. Hãy tải lại.' : 'Mất kết nối, chưa rõ kết quả gửi. Hãy tải lại dữ liệu trước khi thử lại.',
        outcomeUnknown: method != 'GET',
      );
    }
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiError(
        response.statusCode,
        'INVALID_RESPONSE',
        'Máy chủ trả dữ liệu không hợp lệ.',
        outcomeUnknown: response.statusCode >= 200 && response.statusCode < 300,
      );
    }
  }

  ApiError _error(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      /* Never surface HTML, SQL or arbitrary response dumps. */
    }
    final error = body['error'] is Map ? body['error'] as Map : const {};
    return ApiError(
      response.statusCode,
      error['code']?.toString() ?? 'HTTP_ERROR',
      error['message']?.toString() ??
          body['message']?.toString() ??
          'Yêu cầu không thành công.',
      correlationId:
          error['correlationId']?.toString() ??
          response.headers['x-correlation-id'],
    );
  }

  void _acceptTokens(Object? body, int generation) {
    if (generation != _generation) {
      throw const ApiError(
        401,
        'SESSION_CHANGED',
        'Phiên đã thay đổi, hãy đăng nhập lại.',
      );
    }
    if (body is! Map<String, dynamic> ||
        body['role'] != expectedRole ||
        body['accessToken'] is! String ||
        (body['accessToken'] as String).isEmpty ||
        body['refreshToken'] is! String ||
        (body['refreshToken'] as String).isEmpty) {
      throw const ApiError(
        403,
        'ROLE_MISMATCH',
        'Tài khoản không thuộc ứng dụng này hoặc phiên không hợp lệ.',
      );
    }
    _access = body['accessToken'] as String;
    _refresh = body['refreshToken'] as String;
    _store?.write(
      jsonEncode({
        'role': expectedRole,
        'accessToken': _access,
        'refreshToken': _refresh,
      }),
    );
  }

  Future<void> login(String email, String password) async {
    logout();
    final generation = _generation;
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    if (response.statusCode != 200) throw _error(response);
    _acceptTokens(_decode(response), generation);
    notifyListeners();
  }

  Future<void> _refreshOnce() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final generation = _generation;
    final token = _refresh;
    final future = (() async {
      if (token == null) {
        throw const ApiError(401, 'SESSION_EXPIRED', 'Hãy đăng nhập lại.');
      }
      try {
        final response = await _send(
          'POST',
          '/auth/refresh',
          body: {'refreshToken': token},
        );
        if (response.statusCode != 200) throw _error(response);
        _acceptTokens(_decode(response), generation);
      } catch (_) {
        if (generation == _generation) logout();
        rethrow;
      }
    })();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    int expectedStatus = 200,
  }) async {
    final generation = _generation;
    final sentToken = _access;
    if (sentToken == null) {
      throw const ApiError(401, 'SESSION_EXPIRED', 'Hãy đăng nhập lại.');
    }
    var response = await _send(
      method,
      path,
      query: query,
      body: body,
      token: sentToken,
    );
    if (generation != _generation) {
      throw const ApiError(401, 'SESSION_CHANGED', 'Phiên đã thay đổi.');
    }
    if (response.statusCode == 401) {
      if (_access == sentToken) await _refreshOnce();
      if (generation != _generation) {
        throw const ApiError(401, 'SESSION_CHANGED', 'Phiên đã thay đổi.');
      }
      if (method != 'GET') {
        throw const ApiError(
          401,
          'SESSION_REFRESHED',
          'Phiên đã làm mới. Tải lại danh sách trước khi thử lại; thao tác chưa được gửi lại.',
        );
      }
      response = await _send(method, path, query: query, token: _access);
      if (response.statusCode == 401 && generation == _generation) {
        logout();
        throw _error(response);
      }
    }
    if (generation != _generation) {
      throw const ApiError(401, 'SESSION_CHANGED', 'Phiên đã thay đổi.');
    }
    if (response.statusCode != expectedStatus) {
      final failure = _error(response);
      throw ApiError(
        failure.status,
        failure.code,
        failure.message,
        correlationId: failure.correlationId,
        outcomeUnknown:
            method != 'GET' &&
            (response.statusCode >= 500 || response.statusCode < 300),
      );
    }
    // DELETE returns an empty 204; do not JSON-decode it.
    if (expectedStatus == 204) return null;
    return _decode(response);
  }

  /// Authenticated picture call. Returns null when there is no picture (204).
  /// Replacing or removing one's own picture is idempotent, so it may be sent
  /// again once after a token refresh.
  Future<Uint8List?> picture(
    String method, {
    String path = '/avatar/me',
    Uint8List? bytes,
    String? contentType,
  }) async {
    final generation = _generation;
    final sentToken = _access;
    if (sentToken == null) {
      throw const ApiError(401, 'SESSION_EXPIRED', 'Hãy đăng nhập lại.');
    }
    Future<http.Response> send(String token) async {
      final request = http.Request(method, uri(path))
        ..headers['Authorization'] = 'Bearer $token';
      if (bytes != null) {
        request.headers['Content-Type'] = contentType!;
        request.bodyBytes = bytes;
      }
      try {
        return await (() async => http.Response.fromStream(
          await _http.send(request),
        ))().timeout(timeout);
      } on TimeoutException {
        throw const ApiError(0, 'NETWORK_TIMEOUT', 'Hết thời gian xử lý ảnh.');
      } on http.ClientException {
        throw const ApiError(0, 'NETWORK_ERROR', 'Không kết nối được máy chủ.');
      }
    }

    var response = await send(sentToken);
    if (response.statusCode == 401 && generation == _generation) {
      if (_access == sentToken) await _refreshOnce();
      if (generation == _generation) response = await send(_access!);
    }
    if (generation != _generation) {
      throw const ApiError(401, 'SESSION_CHANGED', 'Phiên đã thay đổi.');
    }
    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) throw _error(response);
    return response.bodyBytes;
  }

  @override
  void dispose() {
    _generation++;
    _access = null;
    _refresh = null;
    _http.close();
    super.dispose();
  }
}
