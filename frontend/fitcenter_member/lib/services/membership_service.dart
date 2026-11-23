import 'api_client.dart';
import 'booking_models.dart';

/// Calendar dates from the server, never converted through the device timezone.
String? membershipDate(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    final date = DateTime.tryParse(value);
    if (date != null && date.toIso8601String().startsWith(value)) return value;
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
  static String displayDate(String? value) => value == null
      ? 'Chưa xác định'
      : '${value.substring(8, 10)}/${value.substring(5, 7)}/${value.substring(0, 4)}';
}

class MembershipService {
  final ApiClient api;
  MembershipService(this.api);
  Future<List<Membership>> mine() async =>
      items(await api.request('GET', '/memberships/me'), Membership.fromJson);
}
