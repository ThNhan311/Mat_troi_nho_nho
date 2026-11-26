import 'api_client.dart';

/// Vietnam wall-clock time of a server instant (UTC+07:00, no daylight saving).
DateTime vietnamClock(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 7));

DateTime vietnamToday([DateTime? now]) {
  final t = vietnamClock(now ?? DateTime.now());
  return DateTime.utc(t.year, t.month, t.day);
}

String _two(int v) => v.toString().padLeft(2, '0');
String shortDay(DateTime t) => '${_two(t.day)}/${_two(t.month)}/${t.year}';
String clockText(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
String _isoDay(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

class TrainingSession {
  final DateTime startAt, endAt;
  final String trainerName, status;
  final String? memberName;
  const TrainingSession(
    this.startAt,
    this.endAt,
    this.trainerName,
    this.memberName,
    this.status,
  );

  String get statusLabel => switch (status) {
    'CONFIRMED' => 'Đã đặt',
    'COMPLETED' => 'Đã hoàn tất',
    'CANCELLED' => 'Đã hủy',
    'OPEN' => 'Còn trống',
    _ => status,
  };
}

class Visit {
  final DateTime at;
  final String profileId, name, role;
  const Visit(this.at, this.profileId, this.name, this.role);
}

class ReportService {
  final ApiClient api;
  ReportService(this.api);

  Future<List<TrainingSession>> schedule(DateTime from, DateTime to) => _list(
    '/admin/schedule',
    from,
    to,
    (row) => TrainingSession(
      DateTime.parse(row['startAt'] as String),
      DateTime.parse(row['endAt'] as String),
      row['trainerName'] as String,
      row['memberName'] as String?,
      row['status'] as String,
    ),
  );

  Future<List<Visit>> attendance(DateTime from, DateTime to) => _list(
    '/admin/attendance',
    from,
    to,
    (row) => Visit(
      DateTime.parse(row['at'] as String),
      row['profileId'] as String,
      row['name'] as String,
      row['role'] as String,
    ),
  );

  Future<List<T>> _list<T>(
    String path,
    DateTime from,
    DateTime to,
    T Function(Map<String, dynamic> row) parse,
  ) async {
    final data = await api.request(
      'GET',
      path,
      query: {'from': _isoDay(from), 'to': _isoDay(to)},
    );
    try {
      return [for (final row in data as List) parse(row)];
    } on TypeError {
      throw _invalid;
    } on FormatException {
      throw _invalid;
    }
  }

  static const _invalid = ApiError(
    0,
    'INVALID_RESPONSE',
    'Dữ liệu báo cáo không hợp lệ.',
  );
}
