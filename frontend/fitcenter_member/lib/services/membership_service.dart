import 'api_client.dart';
import 'booking_models.dart';

/// Calendar dates from the server, never converted through the device timezone.
String? membershipDate(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is String && RegExp(r'^[+]?\d{4,7}-\d{2}-\d{2}$').hasMatch(value)) {
    final parts = value.split('-'),
        y = int.parse(parts[0]),
        m = int.parse(parts[1]),
        d = int.parse(parts[2]);
    final leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0),
        days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (y >= 1 && m >= 1 && m <= 12 && d >= 1 && d <= days[m - 1]) return value;
  }
  throw const ApiError(0, 'INVALID_RESPONSE', 'Ngày hội viên không hợp lệ.');
}

class Membership {
  static const labels = {
    'PENDING_ACTIVATION': 'Chờ kích hoạt',
    'ACTIVE': 'Đang hoạt động',
    'SUSPENDED': 'Tạm ngưng',
    'EXPIRED': 'Đã hết hạn',
    'CANCELLED': 'Đã hủy',
  };
  final String id, planId, planName, status;
  final String? startDate, endDate;
  Membership.fromJson(Map<String, dynamic> row)
    : id = uuid(row, 'id'),
      planId = uuid(row, 'planId'),
      planName = text(row, 'planName'),
      status = text(row, 'status'),
      startDate = membershipDate(row, 'startDate'),
      endDate = membershipDate(row, 'endDate') {
    if (!labels.containsKey(status)) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Trạng thái hội viên không được hỗ trợ.',
      );
    }
  }
  String get statusLabel => labels[status]!;
  static String displayDate(String? value) {
    if (value == null) return 'Chưa xác định';
    final p = value.split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }
}

class MembershipService {
  final ApiClient api;
  MembershipService(this.api);
  Future<List<Membership>> mine() async =>
      items(await api.request('GET', '/memberships/me'), Membership.fromJson);
}
