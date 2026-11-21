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
  final String id, memberId, ptId, slotId, status;
  final DateTime startAt, endAt;
  Booking.fromJson(Map<String, dynamic> value)
    : id = uuid(value, 'id'),
      memberId = uuid(value, 'memberId'),
      ptId = uuid(value, 'ptId'),
      slotId = uuid(value, 'slotId'),
      status = text(value, 'status'),
      startAt = instant(value, 'startAt'),
      endAt = instant(value, 'endAt');
}

String shortId(String id) => id.substring(0, 8);
