import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'face_service_config.dart';

enum FaceOutcome { success, rejected, noFace }

class FaceIdentifyResult {
  const FaceIdentifyResult({required this.outcome, this.memberId});

  final FaceOutcome outcome;
  final String? memberId;
}

class FaceEnrollResult {
  const FaceEnrollResult({required this.memberId, required this.samplesUsed});

  final String memberId;
  final int samplesUsed;
}

/// Lỗi từ Face Service hoặc đường truyền. [code] là mã lỗi của hợp đồng API
/// (ví dụ BUSY, UNAUTHORIZED) hoặc NETWORK / TIMEOUT / BAD_RESPONSE.
class FaceServiceException implements Exception {
  const FaceServiceException(this.code, [this.statusCode]);

  final String code;
  final int? statusCode;

  @override
  String toString() => 'FaceServiceException($code, $statusCode)';
}

class FaceServiceClient {
  FaceServiceClient({
    http.Client? httpClient,
    String? baseUrl,
    String? kioskToken,
    Duration? timeout,
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? FaceServiceConfig.baseUrl,
       _kioskToken = kioskToken ?? FaceServiceConfig.kioskToken,
       _timeout = timeout ?? FaceServiceConfig.timeout;

  final http.Client _http;
  final String _baseUrl;
  final String _kioskToken;
  final Duration _timeout;

  /// Nhận diện 1:N. Gửi 1-5 frame JPEG của cùng một người.
  Future<FaceIdentifyResult> identify(List<Uint8List> frames) async {
    final body = await _send(
      path: '/v1/identify',
      tokenHeader: 'X-Kiosk-Token',
      token: _kioskToken,
      frames: frames,
    );

    switch (body['outcome']) {
      case 'SUCCESS':
        final memberId = body['member_id'];
        if (memberId is! String || memberId.isEmpty) {
          throw const FaceServiceException('BAD_RESPONSE');
        }
        return FaceIdentifyResult(
          outcome: FaceOutcome.success,
          memberId: memberId,
        );
      case 'REJECTED':
        return const FaceIdentifyResult(outcome: FaceOutcome.rejected);
      case 'NO_FACE':
        return const FaceIdentifyResult(outcome: FaceOutcome.noFace);
      default:
        throw const FaceServiceException('BAD_RESPONSE');
    }
  }

  /// Đăng ký khuôn mặt (Admin). Gửi 5-15 frame JPEG.
  Future<FaceEnrollResult> enroll({
    required String memberId,
    required String adminToken,
    required List<Uint8List> frames,
  }) async {
    final body = await _send(
      path: '/v1/enroll',
      tokenHeader: 'X-Admin-Token',
      token: adminToken,
      frames: frames,
      fields: {'member_id': memberId},
    );

    final id = body['member_id'];
    final samples = body['samples_used'];
    if (id is! String || samples is! int) {
      throw const FaceServiceException('BAD_RESPONSE');
    }
    return FaceEnrollResult(memberId: id, samplesUsed: samples);
  }

  /// Xóa khuôn mặt (Admin). Không có sẵn cũng coi là đã xóa.
  Future<void> remove({
    required String memberId,
    required String adminToken,
  }) async {
    final http.Response response;
    try {
      response = await _http
          .delete(
            Uri.parse('$_baseUrl/v1/members/${Uri.encodeComponent(memberId)}'),
            headers: {'X-Admin-Token': adminToken},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const FaceServiceException('TIMEOUT');
    } catch (_) {
      throw const FaceServiceException('NETWORK');
    }
    if (response.statusCode != 200 && response.statusCode != 404) {
      throw FaceServiceException('BAD_RESPONSE', response.statusCode);
    }
  }

  Future<Map<String, dynamic>> _send({
    required String path,
    required String tokenHeader,
    required String token,
    required List<Uint8List> frames,
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'))
      ..headers[tokenHeader] = token
      ..fields.addAll(fields);

    for (var i = 0; i < frames.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'frames',
          frames[i],
          filename: 'frame$i.jpg',
        ),
      );
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      ).timeout(_timeout);
    } on TimeoutException {
      throw const FaceServiceException('TIMEOUT');
    } catch (_) {
      throw const FaceServiceException('NETWORK');
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Giữ json = null, xử lý bên dưới.
    }

    if (response.statusCode != 200) {
      final code = json?['error'];
      throw FaceServiceException(
        code is String ? code : 'BAD_RESPONSE',
        response.statusCode,
      );
    }
    if (json == null) throw const FaceServiceException('BAD_RESPONSE');
    return json;
  }

  void close() => _http.close();
}
