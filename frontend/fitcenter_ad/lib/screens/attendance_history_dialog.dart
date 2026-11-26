import 'package:flutter/material.dart';

import '../services/report_service.dart';
import 'report_pages.dart';

/// How far back the account list and this dialog look.
const attendanceDays = 90;

/// One person's check-ins, newest first.
class AttendanceHistoryDialog extends StatelessWidget {
  final String name;
  final List<Visit> visits;
  const AttendanceHistoryDialog({
    super.key,
    required this.name,
    required this.visits,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Lịch sử check-in: $name'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visits.isEmpty
                  ? 'Chưa có lượt check-in nào trong $attendanceDays ngày qua.'
                  : '${visits.length} lượt trong $attendanceDays ngày qua.',
            ),
            if (visits.isNotEmpty) ...[
              const SizedBox(height: 12),
              ReportTable(
                columns: const ['Ngày', 'Giờ vào'],
                rows: [
                  for (final v in visits)
                    [
                      shortDay(vietnamClock(v.at)),
                      clockText(vietnamClock(v.at)),
                    ],
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      FilledButton(
        key: const Key('history-close'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
