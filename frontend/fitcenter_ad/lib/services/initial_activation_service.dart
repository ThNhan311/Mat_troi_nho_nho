import 'dart:math';

import 'api_client.dart';
import 'admin_account_service.dart';
import 'membership_plan_service.dart';

String newActivationKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String requiredUuid(dynamic v) {
  if (v is! String ||
      !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
          .hasMatch(v))
    throw const FormatException('UUID');
  return v;
}

String calendarDate(dynamic v) {
  if (v is! String || !RegExp(r'^[+]?\d{4,7}-\d{2}-\d{2}$').hasMatch(v))
    throw const FormatException('DATE');
  final parts = v.split('-'),
      y = int.parse(parts[0]),
      m = int.parse(parts[1]),
      d = int.parse(parts[2]);
  final leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0),
      days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (y < 1 || m < 1 || m > 12 || d < 1 || d > days[m - 1])
    throw const FormatException('DATE');
  return v;
}

String showCalendar(String value) {
  final p = value.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

class InitialActivation {
  final String id,
      requestId,
      memberId,
      membershipId,
      planId,
      planName,
      startDate,
      endDate,
      receiptRef,
      paymentId;
  final int cents, days;
  final DateTime confirmedAt;
  InitialActivation._(
    this.id,
    this.requestId,
    this.memberId,
    this.membershipId,
    this.planId,
    this.planName,
    this.startDate,
    this.endDate,
    this.receiptRef,
    this.paymentId,
    this.cents,
    this.days,
    this.confirmedAt,
  );
  static InitialActivation parse(dynamic data, {bool write = false}) {
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      final ms = data['membership'],
          pay = data['payment'],
          receipt = data['receipt'],
          snap = data['planSnapshot'];
      if (ms is! Map<String, dynamic> ||
          pay is! Map<String, dynamic> ||
          receipt is! Map<String, dynamic> ||
          snap is! Map<String, dynamic>)
        throw const FormatException();
      final plan = MembershipPlan.parse({
        'id': ms['planId'],
        'name': snap['name'],
        'description': null,
        'durationDays': snap['durationDays'],
        'price': snap['listedPrice'],
      });
      if (ms['status'] != 'ACTIVE' ||
          pay['status'] != 'SUCCESS' ||
          pay['provider'] != 'COUNTER' ||
          snap['currency'] != 'VND' ||
          ms['planName'] != plan.name ||
          receipt['receiptRef'] is! String ||
          (receipt['receiptRef'] as String).trim().isEmpty ||
          pay['amount'] is! num ||
          num.parse(decimalPrice(plan.cents)) != pay['amount'])
        throw const FormatException();
      requiredUuid(receipt['confirmedByUserId']);
      final at = receipt['confirmedAt'];
      if (at is! String || !at.endsWith('Z')) throw const FormatException();
      final time = DateTime.parse(at).toUtc();
      if (pay['processedAt'] != at ||
          pay['providerRef'] != 'counter:${pay['id']}')
        throw const FormatException();
      return InitialActivation._(
        requiredUuid(data['activationId']),
        requiredUuid(data['requestId']),
        requiredUuid(data['memberId']),
        requiredUuid(ms['id']),
        plan.id,
        plan.name,
        calendarDate(ms['startDate']),
        calendarDate(ms['endDate']),
        receipt['receiptRef'],
        requiredUuid(pay['id']),
        plan.cents,
        plan.durationDays,
        time,
      );
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả kích hoạt không hợp lệ. Hãy đọc lại để đối chiếu.',
        outcomeUnknown: write,
      );
    }
  }
}

class InitialActivationService {
  final ApiClient api;
  InitialActivationService(this.api);
  Future<List<AdminAccount>> members() =>
      AdminAccountService(api).list('MEMBER');
  Future<List<MembershipPlan>> plans() => MembershipPlanService(api).list();
  Future<InitialActivation> create(
    String member,
    String key,
    Map<String, dynamic> payload,
  ) async {
    final result = InitialActivation.parse(
      await api.request(
        'POST',
        '/admin/members/$member/activate-membership',
        body: payload,
        idempotencyKey: key,
        acceptedStatuses: {200, 201},
      ),
      write: true,
    );
    if (result.memberId != member ||
        result.requestId != key ||
        result.planId != payload['planId'] ||
        num.parse(decimalPrice(result.cents)) != payload['amountCollected'])
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả không khớp yêu cầu. Hãy đọc lại để đối chiếu.',
        outcomeUnknown: true,
      );
    return result;
  }

  Future<InitialActivation> read(String member) async {
    final result = InitialActivation.parse(
      await api.request('GET', '/admin/members/$member/membership-activation'),
    );
    if (result.memberId != member)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Bản ghi không thuộc Member đã chọn.',
      );
    return result;
  }
}
