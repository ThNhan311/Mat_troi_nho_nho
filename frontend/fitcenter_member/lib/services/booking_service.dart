import 'dart:convert';

import 'package:http/http.dart' as http;

class BookingService {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  Future<Map<String, dynamic>> createBooking({
    required String ptId,
    required String slotId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ptId': ptId,
        'slotId': slotId,
      }),
    );

    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode == 201) {
      return body;
    }

    if (response.statusCode == 409) {
      throw Exception(
        body['message'] ??
            'Khung giờ này đã được người khác đặt.',
      );
    }

    if (response.statusCode == 401) {
      throw Exception(
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        body['message'] ??
            'Bạn không có quyền thực hiện thao tác này.',
      );
    }

    throw Exception(
      body['message'] ??
          'Không thể đặt lịch. Mã lỗi: ${response.statusCode}',
    );
  }

  Future<List<Map<String, dynamic>>> getMyBookings({
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings/me');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Không thể tải lịch sử đặt lịch.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded
          .map(
            (item) => Map<String, dynamic>.from(
          item as Map,
        ),
      )
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> cancelBooking({
    required String bookingId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/bookings/$bookingId/cancel',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode == 200) {
      return body;
    }

    if (response.statusCode == 409) {
      throw Exception(
        body['message'] ??
            'Không thể hủy lịch ở thời điểm này.',
      );
    }

    throw Exception(
      body['message'] ??
          'Không thể hủy lịch. Mã lỗi: ${response.statusCode}',
    );
  }
}