import 'api_client.dart';

const policyPath = '/admin/booking-policy';
const maxPolicyInteger = 2147483647;

String? validatePolicyInteger(String? text, int minimum) {
  final value = text?.trim() ?? '';
  final number = RegExp(r'^[+-]?[0-9]+$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  if (number == null || number > maxPolicyInteger) {
    return 'Nhập số nguyên trong phạm vi int32.';
  }
  if (number < minimum) return 'Giá trị phải từ $minimum trở lên.';
  return null;
}

class BookingPolicy {
  final String id;
  final int maxAdvanceDays,
      minNoticeHours,
      cancelDeadlineHours,
      maxFutureBookings;
  final DateTime effectiveFrom;
  const BookingPolicy(
    this.id,
    this.maxAdvanceDays,
    this.minNoticeHours,
    this.cancelDeadlineHours,
    this.maxFutureBookings,
    this.effectiveFrom,
  );
  Map<String, int> get configuration => {
    'maxAdvanceDays': maxAdvanceDays,
    'minNoticeHours': minNoticeHours,
    'cancelDeadlineHours': cancelDeadlineHours,
    'maxFutureBookings': maxFutureBookings,
  };
  static BookingPolicy parse(dynamic data, {bool write = false}) {
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      final id = data['id'];
      if (id is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
              .hasMatch(id))
        throw const FormatException();
      int number(String key, int minimum) {
        final n = data[key];
        if (n is! int || n < minimum || n > maxPolicyInteger)
          throw const FormatException();
        return n;
      }

      final time = data['effectiveFrom'];
      if (time is! String ||
          !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(time))
        throw const FormatException();
      return BookingPolicy(
        id,
        number('maxAdvanceDays', 1),
        number('minNoticeHours', 0),
        number('cancelDeadlineHours', 0),
        number('maxFutureBookings', 1),
        DateTime.parse(time).toUtc(),
      );
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu chính sách từ máy chủ không hợp lệ.',
        outcomeUnknown: write,
      );
    }
  }
}

class BookingPolicyService {
  final ApiClient api;
  BookingPolicyService(this.api);
  Future<BookingPolicy?> read() async {
    try {
      return BookingPolicy.parse(await api.request('GET', policyPath));
    } on ApiError catch (e) {
      if (e.status == 404 && e.code == 'BOOKING_POLICY_NOT_FOUND') return null;
      rethrow;
    }
  }

  Future<BookingPolicy> save(Map<String, int> fields) async {
    final result = BookingPolicy.parse(
      await api.request('PUT', policyPath, body: fields),
      write: true,
    );
    if (fields.length != 4 ||
        result.configuration.entries.any(
          (entry) => fields[entry.key] != entry.value,
        )) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả lưu chưa thể đối chiếu. Vui lòng tải lại chính sách.',
        outcomeUnknown: true,
      );
    }
    return result;
  }
}
