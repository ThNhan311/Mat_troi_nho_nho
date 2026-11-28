import 'api_client.dart';

Map<String, dynamic> object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const ApiError(
    0,
    'INVALID_RESPONSE',
    'Dữ liệu máy chủ không đúng contract.',
  );
}

String text(Map<String, dynamic> value, String key) {
  if (value[key] is String) return value[key] as String;
  throw const ApiError(0, 'INVALID_RESPONSE', 'Thiếu trường dữ liệu bắt buộc.');
}

String uuid(Map<String, dynamic> value, String key) {
  final id = text(value, key);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    throw const ApiError(
      0,
      'INVALID_RESPONSE',
      'Định danh máy chủ không phải UUID.',
    );
  }
  return id;
}

DateTime instant(Map<String, dynamic> value, String key) {
  final raw = text(value, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw)) {
    throw const ApiError(
      0,
      'INVALID_RESPONSE',
      'Thời gian máy chủ phải có offset.',
    );
  }
  return parsed.toUtc();
}

List<T> items<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) {
    throw const ApiError(
      0,
      'INVALID_RESPONSE',
      'Máy chủ phải trả một danh sách.',
    );
  }
  return value.map((row) => parse(object(row))).toList(growable: false);
}

class Trainer {
  final String id, fullName;
  final String? bio, specialization, experienceSummary;
  Trainer.fromJson(Map<String, dynamic> value)
    : id = uuid(value, 'id'),
      fullName = text(value, 'fullName'),
      bio = value['bio'] as String?,
      specialization = value['specialization'] as String?,
      experienceSummary = value['experienceSummary'] as String?;
}

class Slot {
  final String id, ptId, status;
  final DateTime startAt, endAt;
  Slot.fromJson(Map<String, dynamic> value)
    : id = uuid(value, 'id'),
      ptId = uuid(value, 'ptId'),
      status = text(value, 'status'),
      startAt = instant(value, 'startAt'),
      endAt = instant(value, 'endAt');
}

class Booking {
  final String? cancelledBy, cancelReason;
  final DateTime? cancelledAt, completedAt;
  final String id, memberId, ptId, slotId, status;
  final DateTime startAt, endAt;
  Booking.fromJson(Map<String, dynamic> value)
    : cancelledBy = value['cancelledBy'] as String?,
      cancelReason = value['cancelReason'] as String?,
      cancelledAt = value['cancelledAt'] == null
          ? null
          : instant(value, 'cancelledAt'),
      completedAt = value['completedAt'] == null
          ? null
          : instant(value, 'completedAt'),
      id = uuid(value, 'id'),
      memberId = uuid(value, 'memberId'),
      ptId = uuid(value, 'ptId'),
      slotId = uuid(value, 'slotId'),
      status = text(value, 'status'),
      startAt = instant(value, 'startAt'),
      endAt = instant(value, 'endAt');
}

String shortId(String id) => id.substring(0, 8);

/// What the trainer may see about a student who booked them.
class BookedMember {
  const BookedMember(this.name, {this.phone, this.gender});

  final String name;
  final String? phone, gender;
}

Booking transitioned(
  Object? payload,
  Booking previous,
  String status, {
  String? actor,
}) {
  try {
    final next = Booking.fromJson(object(payload));
    if (next.id != previous.id ||
        next.memberId != previous.memberId ||
        next.ptId != previous.ptId ||
        next.slotId != previous.slotId ||
        next.startAt != previous.startAt ||
        next.endAt != previous.endAt ||
        next.status != status ||
        (status == 'CANCELLED' &&
            (next.cancelledAt == null || next.cancelledBy != actor)) ||
        (status == 'COMPLETED' && next.completedAt == null))
      throw const FormatException();
    return next;
  } catch (_) {
    throw const ApiError(
      200,
      'INVALID_RESPONSE',
      'Chưa xác nhận được kết quả. Tải lại dữ liệu để đối chiếu.',
      outcomeUnknown: true,
    );
  }
}

class ServiceEligibility {
  final bool eligible;
  final DateTime checkedAt;
  final List<String> reasonCodes;
  ServiceEligibility._(this.eligible, this.checkedAt, this.reasonCodes);
  factory ServiceEligibility.fromJson(Map<String, dynamic> value) {
    final reasons = value['reasonCodes'];
    if (value['eligible'] is! bool ||
        reasons is! List ||
        reasons.any((r) => r is! String) ||
        value['eligible'] != reasons.isEmpty) {
      throw const ApiError(
        200,
        'INVALID_RESPONSE',
        'Kết quả kiểm tra điều kiện không hợp lệ.',
      );
    }
    return ServiceEligibility._(
      value['eligible'] as bool,
      instant(value, 'checkedAt'),
      List<String>.unmodifiable(reasons),
    );
  }
}

String eligibilityReason(String code) =>
    const {
      'BOOKING_NOT_CONFIRMED': 'Buổi tập không còn ở trạng thái Đã xác nhận.',
      'SESSION_NOT_STARTED': 'Chưa đến giờ buổi tập.',
      'SESSION_ENDED': 'Buổi tập đã hết giờ.',
      'MEMBER_ACCOUNT_INACTIVE': 'Tài khoản hội viên không hợp lệ.',
      'MEMBERSHIP_INACTIVE': 'Gói tập hiện tại không hợp lệ.',
      'MEMBERSHIP_NOT_COVERED': 'Gói tập không bao phủ toàn bộ buổi tập.',
    }[code] ??
    'Không đủ điều kiện ($code).';
