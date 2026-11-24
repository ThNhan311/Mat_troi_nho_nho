import 'dart:math';

import 'api_client.dart';

String newPaymentKey() {
  final random = Random.secure(),
      b = List.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String paymentUuid(dynamic value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
          .hasMatch(value))
    throw const FormatException('UUID');
  return value;
}

String paidDate(dynamic value) {
  if (value is! String || !RegExp(r'^\+?\d{4,7}-\d{2}-\d{2}$').hasMatch(value))
    throw const FormatException('DATE');
  final p = value.split('-'),
      y = int.parse(p[0]),
      m = int.parse(p[1]),
      d = int.parse(p[2]);
  final days = [
    31,
    y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  if (y < 1 || m < 1 || m > 12 || d < 1 || d > days[m - 1])
    throw const FormatException('DATE');
  return value;
}

String showPaidDate(String value) {
  final p = value.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

int exactPaymentCents(dynamic value) {
  if (value is! String || !RegExp(r'^\d{1,10}\.\d{2}$').hasMatch(value))
    throw const FormatException('Decimal');
  final p = value.split('.');
  return int.parse(p[0]) * 100 + int.parse(p[1]);
}

String paymentDecimal(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
String paymentTime(DateTime value) =>
    '${value.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 19).replaceFirst('T', ' ')} (giờ Việt Nam)';

class RenewalPayment {
  final String id,
      requestId,
      membershipId,
      memberId,
      planId,
      planName,
      providerRef,
      status,
      fulfillment;
  final int cents, days;
  final String? periodId, start, end, reason;
  final DateTime createdAt;
  RenewalPayment._(
    this.id,
    this.requestId,
    this.membershipId,
    this.memberId,
    this.planId,
    this.planName,
    this.providerRef,
    this.status,
    this.fulfillment,
    this.cents,
    this.days,
    this.periodId,
    this.start,
    this.end,
    this.reason,
    this.createdAt,
  );
  static RenewalPayment parse(dynamic data, {bool write = false}) {
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      final id = paymentUuid(data['id']),
          days = data['durationDays'],
          name = data['planName'],
          state = data['status'],
          fulfillment = data['fulfillmentStatus'];
      if (days is! int ||
          days < 1 ||
          days > 2147483647 ||
          name is! String ||
          name.trim().isEmpty ||
          data['provider'] != 'SIMULATOR' ||
          data['providerRef'] != 'sim:$id' ||
          data['currency'] != 'VND' ||
          !{'PENDING', 'SUCCESS', 'FAILED', 'CANCELLED'}.contains(state) ||
          !{
            'NOT_APPLIED',
            'APPLIED',
            'RECONCILIATION_REQUIRED',
          }.contains(fulfillment))
        throw const FormatException();
      final start = data['periodStart'] == null
              ? null
              : paidDate(data['periodStart']),
          end = data['periodEnd'] == null ? null : paidDate(data['periodEnd']),
          period = data['periodId'] == null
              ? null
              : paymentUuid(data['periodId']),
          reason = data['reconciliationReason'];
      if ((fulfillment == 'APPLIED') !=
              (period != null || start != null || end != null) ||
          (state == 'SUCCESS') != (fulfillment != 'NOT_APPLIED') ||
          (fulfillment == 'APPLIED') !=
              (period != null && start != null && end != null) ||
          (fulfillment == 'RECONCILIATION_REQUIRED') !=
              (reason is String && reason.isNotEmpty))
        throw const FormatException();
      if (data['createdAt'] is! String ||
          !(data['createdAt'] as String).endsWith('Z'))
        throw const FormatException();
      return RenewalPayment._(
        id,
        paymentUuid(data['requestId']),
        paymentUuid(data['membershipId']),
        paymentUuid(data['memberId']),
        paymentUuid(data['planId']),
        name,
        data['providerRef'],
        state,
        fulfillment,
        exactPaymentCents(data['amount']),
        days,
        period,
        start,
        end,
        reason as String?,
        DateTime.parse(data['createdAt']).toUtc(),
      );
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu giao dịch từ máy chủ không hợp lệ.',
        outcomeUnknown: write,
      );
    }
  }

  String get statusLabel => const {
    'PENDING': 'Chờ kết quả mô phỏng',
    'SUCCESS': 'Đã ghi nhận SUCCESS',
    'FAILED': 'Thất bại',
    'CANCELLED': 'Đã hủy',
  }[status]!;
  String get fulfillmentLabel => fulfillment == 'APPLIED'
      ? 'Đã cấp kỳ sử dụng'
      : fulfillment == 'RECONCILIATION_REQUIRED'
      ? 'Cần đối soát; chưa cấp kỳ sử dụng'
      : 'Chưa cấp kỳ sử dụng';
}

class PaidPeriod {
  final String id, planId, source, start, end, phase;
  final String? name;
  final int? cents, days;
  PaidPeriod._(
    this.id,
    this.planId,
    this.source,
    this.start,
    this.end,
    this.phase,
    this.name,
    this.cents,
    this.days,
  );
  static PaidPeriod parse(dynamic data) {
    try {
      if (data is! Map<String, dynamic> ||
          !{
            'LEGACY_AGGREGATE',
            'INITIAL_COUNTER',
            'RENEWAL',
          }.contains(data['source']) ||
          !{'CURRENT', 'NEXT', 'HISTORY'}.contains(data['phase']))
        throw const FormatException();
      final legacy = data['source'] == 'LEGACY_AGGREGATE';
      if (!legacy &&
          (data['planName'] is! String ||
              data['durationDays'] is! int ||
              data['durationDays'] < 1 ||
              data['currency'] != 'VND'))
        throw const FormatException();
      return PaidPeriod._(
        paymentUuid(data['id']),
        paymentUuid(data['planId']),
        data['source'],
        paidDate(data['startDate']),
        paidDate(data['endDate']),
        data['phase'],
        data['planName'] as String?,
        data['amount'] == null ? null : exactPaymentCents(data['amount']),
        data['durationDays'] as int?,
      );
    } catch (_) {
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu kỳ sử dụng không hợp lệ.',
      );
    }
  }

  String get phaseLabel => const {
    'CURRENT': 'Kỳ hiện tại',
    'NEXT': 'Kỳ kế tiếp',
    'HISTORY': 'Lịch sử',
  }[phase]!;
}
