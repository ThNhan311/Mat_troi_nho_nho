import 'api_client.dart';
import 'booking_policy_service.dart' show validatePolicyInteger;

String? validatePlanName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Vui lòng nhập tên gói';
  if (value.runes.length > 100 || value.contains('\u0000')) {
    return 'Tên gói tối đa 100 ký tự, không chứa ký tự rỗng.';
  }
  return null;
}

String? validateDurationDays(String? value) => validatePolicyInteger(value, 1);

/// The server stores days only, so a month and a year are fixed lengths.
enum DurationUnit {
  day('Ngày', 1),
  month('Tháng', 30),
  year('Năm', 365);

  final String label;
  final int days;
  const DurationUnit(this.label, this.days);

  /// The largest unit that divides the number of days exactly.
  static DurationUnit of(int days) => days % year.days == 0
      ? year
      : days % month.days == 0
      ? month
      : day;
}

String? validateDuration(String? value, DurationUnit unit) {
  final error = validateDurationDays(value);
  if (error != null) return error;
  return validateDurationDays('${int.parse(value!.trim()) * unit.days}') == null
      ? null
      : 'Thời hạn quá dài.';
}

/// "1 năm (365 ngày)", "3 tháng (90 ngày)" or "37 ngày".
String durationText(int days) {
  final unit = DurationUnit.of(days);
  return unit == DurationUnit.day
      ? '$days ngày'
      : '${days ~/ unit.days} ${unit.label.toLowerCase()} ($days ngày)';
}

/// Decimal text -> exact cents; no rounding, month conversion or business cap.
int? priceCents(String text) {
  final value = text.trim();
  if (!RegExp(r'^\+?[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(value)) return null;
  final parts = value.replaceFirst('+', '').split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 9999999999) return null;
  final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return whole * 100 + fraction;
}

String? validatePlanPrice(String? value) => priceCents(value ?? '') == null
    ? 'Nhập giá từ 0 đến 9999999999.99, tối đa 2 số thập phân.'
    : null;
String decimalPrice(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// For reading: 100000 is shown as "100.000 VND"; cents only when there are any.
String moneyText(int cents) {
  final whole = '${cents ~/ 100}';
  final grouped = whole.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (_) => '.',
  );
  final rest = cents % 100;
  return '$grouped${rest == 0 ? '' : ',${rest.toString().padLeft(2, '0')}'} VND';
}

class MembershipPlan {
  final String id, name;
  final String? description;
  final int durationDays, cents;
  const MembershipPlan(
    this.id,
    this.name,
    this.description,
    this.durationDays,
    this.cents,
  );
  static MembershipPlan parse(dynamic data, {bool write = false}) {
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      final id = data['id'],
          name = data['name'],
          days = data['durationDays'],
          price = data['price'],
          description = data['description'];
      if (id is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
              .hasMatch(id) ||
          name is! String ||
          validatePlanName(name) != null ||
          days is! int ||
          days < 1 ||
          days > 2147483647 ||
          price is! num ||
          !price.isFinite ||
          price < 0 ||
          price > 9999999999.99 ||
          (description != null && description is! String))
        throw const FormatException();
      final text = price.toStringAsFixed(2);
      if (num.parse(text) != price) throw const FormatException();
      final cents = priceCents(text);
      if (cents == null) throw const FormatException();
      return MembershipPlan(id, name, description as String?, days, cents);
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu gói tập từ máy chủ không hợp lệ.',
        outcomeUnknown: write,
      );
    }
  }
}

class MembershipPlanService {
  final ApiClient api;
  MembershipPlanService(this.api);
  Future<List<MembershipPlan>> list() async {
    final data = await api.request('GET', '/membership-plans');
    if (data is! List)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Danh sách gói tập không hợp lệ.',
      );
    return data.map((e) => MembershipPlan.parse(e)).toList();
  }

  Future<MembershipPlan> update(
    String id, {
    required String name,
    String? description,
    required int durationDays,
    required int cents,
  }) async {
    final result = MembershipPlan.parse(
      await api.request(
        'PUT',
        '/admin/membership-plans/$id',
        body: {
          'name': name,
          'description': description,
          'durationDays': durationDays,
          'price': num.parse(decimalPrice(cents)),
        },
      ),
      write: true,
    );
    if (result.id != id ||
        result.name != name ||
        result.durationDays != durationDays ||
        result.cents != cents) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa đối chiếu được kết quả sửa. Hãy tải lại danh sách.',
        outcomeUnknown: true,
      );
    }
    return result;
  }

  /// true when the plan was only withdrawn from sale because somebody bought it.
  Future<bool> delete(String id) async {
    final data = await api.request('DELETE', '/admin/membership-plans/$id');
    final result = data is Map ? data['result'] : null;
    if (result != 'DELETED' && result != 'ARCHIVED') {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa đối chiếu được kết quả xóa. Hãy tải lại danh sách.',
        outcomeUnknown: true,
      );
    }
    return result == 'ARCHIVED';
  }

  Future<MembershipPlan> create({
    required String name,
    String? description,
    required int durationDays,
    required int cents,
  }) async {
    final result = MembershipPlan.parse(
      await api.request(
        'POST',
        '/admin/membership-plans',
        expectedStatus: 201,
        body: {
          'name': name,
          'description': description,
          'durationDays': durationDays,
          'price': num.parse(decimalPrice(cents)),
        },
      ),
      write: true,
    );
    if (result.name != name ||
        result.description != description ||
        result.durationDays != durationDays ||
        result.cents != cents) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa đối chiếu được kết quả tạo. Hãy tải lại danh sách.',
        outcomeUnknown: true,
      );
    }
    return result;
  }
}
