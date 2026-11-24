import 'api_client.dart';
import 'renewal_models.dart';

class PaymentSimulatorService {
  final ApiClient api;
  PaymentSimulatorService(this.api);
  Future<List<RenewalPayment>> list() async {
    final data = await api.request(
      'GET',
      '/admin/payment-simulator/transactions',
    );
    if (data is! List)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Danh sách giao dịch không hợp lệ.',
      );
    return data.map((x) => RenewalPayment.parse(x)).toList();
  }

  Future<List<Map<String, dynamic>>> events(String id) async {
    final data = await api.request(
      'GET',
      '/admin/payment-simulator/transactions/$id/events',
    );
    if (data is! List || data.any((x) => x is! Map<String, dynamic>))
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Danh sách sự kiện không hợp lệ.',
      );
    return data.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> command(RenewalPayment p, String state, String event) =>
      {
        'eventId': event,
        'providerRef': p.providerRef,
        'amount': num.parse(paymentDecimal(p.cents)),
        'currency': 'VND',
        'status': state,
      };
  Future<RenewalPayment> send(String id, Map<String, dynamic> command) async {
    final data = await api.request(
      'POST',
      '/admin/payment-simulator/transactions/$id/results',
      body: command,
    );
    final payment = RenewalPayment.parse(data, write: true);
    if (payment.id != id ||
        data is! Map<String, dynamic> ||
        data['eventId'] != command['eventId'])
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả không khớp yêu cầu.',
        outcomeUnknown: true,
      );
    return payment;
  }
}
