/// Business display uses UTC+07:00, independent of the browser's timezone.
String vietnamTime(DateTime instant) {
  final vn = instant.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(vn.day)}/${two(vn.month)}/${vn.year} ${two(vn.hour)}:${two(vn.minute)} (giờ Việt Nam, UTC+07:00)';
}

DateTime parseVietnamInput(String raw) {
  if (!RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d$').hasMatch(raw)) {
    throw const FormatException('Dùng YYYY-MM-DD HH:mm theo giờ Việt Nam.');
  }
  final parsed = DateTime.tryParse('${raw.replaceFirst(' ', 'T')}:00+07:00');
  if (parsed == null) throw const FormatException('Ngày giờ không hợp lệ.');
  final local = parsed
      .toUtc()
      .add(const Duration(hours: 7))
      .toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' ');
  if (local != raw) throw const FormatException('Ngày giờ không hợp lệ.');
  return parsed.toUtc();
}

Map<String, String> queryRange(DateTime from, DateTime to) => {
  'from': from.toUtc().toIso8601String(),
  'to': to.toUtc().toIso8601String(),
};
