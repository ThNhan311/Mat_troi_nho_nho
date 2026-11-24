import 'api_client.dart';
import 'renewal_models.dart';

class RenewalPlan {
  final String id, name;
  final int days, cents;
  RenewalPlan(this.id, this.name, this.days, this.cents);
  static RenewalPlan parse(dynamic data) {
    try {
      if (data is! Map<String, dynamic> ||
          data['name'] is! String ||
          data['durationDays'] is! int ||
          data['durationDays'] < 1 ||
          data['price'] is! num)
        throw const FormatException();
      final n = data['price'] as num;
      if (!n.isFinite ||
          n < 0 ||
          n > 9999999999.99 ||
          num.parse(n.toStringAsFixed(2)) != n)
        throw const FormatException();
      return RenewalPlan(
        paymentUuid(data['id']),
        data['name'],
        data['durationDays'],
        exactPaymentCents(n.toStringAsFixed(2)),
      );
    } catch (_) {
      throw const ApiError(0, 'INVALID_RESPONSE', 'Dữ liệu gói không hợp lệ.');
    }
  }
}

class RenewalService {
  final ApiClient api;
  RenewalService(this.api);
  Future<List<RenewalPlan>> plans() async {
    final rows = await api.request('GET', '/membership-plans');
    if (rows is! List)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Danh sách gói không hợp lệ.',
      );
    return rows.map(RenewalPlan.parse).toList();
  }

  Future<List<RenewalPayment>> payments() async {
    final rows = await api.request('GET', '/payments/me');
    if (rows is! List)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Danh sách giao dịch không hợp lệ.',
      );
    return rows.map((x) => RenewalPayment.parse(x)).toList();
  }

  Future<List<PaidPeriod>> periods(String membership) async {
    final data = await api.request('GET', '/memberships/$membership/periods');
    if (data is! Map<String, dynamic> ||
        data['membershipId'] != membership ||
        data['periods'] is! List ||
        data['checkedAt'] is! String ||
        !(data['checkedAt'] as String).endsWith('Z'))
      throw const ApiError(0, 'INVALID_RESPONSE', 'Lịch sử kỳ không hợp lệ.');
    return (data['periods'] as List).map(PaidPeriod.parse).toList();
  }

  Future<RenewalPayment> create(
    String membership,
    String plan,
    String key,
  ) async {
    final data = await api.request(
      'POST',
      '/memberships/$membership/renewals',
      body: {'planId': plan},
      idempotencyKey: key,
      acceptedStatuses: {200, 201},
    );
    final payment = RenewalPayment.parse(data, write: true);
    if (payment.membershipId != membership ||
        payment.planId != plan ||
        payment.requestId != key)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Giao dịch không khớp yêu cầu.',
        outcomeUnknown: true,
      );
    return payment;
  }
}
