import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fitcenter_pt/services/api_client.dart';

import 'original_ui_test.dart' show auth, enter, tap;
import 'widget_test.dart' as f;

Map<String, dynamic> session(
  int number,
  String status,
  Duration fromNow, [
  Map<String, dynamic> more = const {},
]) {
  final start = DateTime.now().toUtc().add(fromNow);
  return {
    ...f.booking(),
    'id': '3000000$number-0000-0000-0000-000000000003',
    'status': status,
    'startAt': start.toIso8601String(),
    'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
    ...more,
  };
}

Finder card(int number) =>
    find.byKey(ValueKey('session-3000000$number-0000-0000-0000-000000000003'));

void main() {
  testWidgets('sessions are split by outcome, overdue ones first', (t) async {
    final ranges = <Duration>[];
    final api = ApiClient(
      expectedRole: 'PT',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(auth());
        if (path.endsWith('/pt/bookings')) {
          ranges.add(
            DateTime.now().toUtc().difference(
              DateTime.parse(r.url.queryParameters['from']!),
            ),
          );
          return f.json([
            session(1, 'CONFIRMED', const Duration(days: 2)),
            session(2, 'CONFIRMED', const Duration(days: -3)),
            session(3, 'COMPLETED', const Duration(days: -5), {
              'completedAt': DateTime.now().toUtc().toIso8601String(),
            }),
            session(4, 'CANCELLED', const Duration(days: -1), {
              'cancelledBy': 'MEMBER',
              'cancelledAt': DateTime.now().toUtc().toIso8601String(),
              'cancelReason': 'Ban viec',
            }),
          ]);
        }
        return f.json([]);
      }),
    );
    addTearDown(api.dispose);
    await enter(t, api);
    await tap(t, find.text('Buổi tập').last);
    // The history is really asked for.
    expect(ranges.any((back) => back.inDays >= 60), isTrue);

    expect(find.text('Sắp tới (2)'), findsOneWidget);
    expect(find.text('Cần hoàn tất (1)'), findsOneWidget);
    expect(card(1), findsOneWidget);
    expect(card(2), findsOneWidget);
    expect(card(3), findsNothing);
    expect(t.getTopLeft(card(2)).dy, lessThan(t.getTopLeft(card(1)).dy));

    await tap(t, find.text('Đã dạy'));
    expect(card(3), findsOneWidget);
    expect(card(1), findsNothing);

    await tap(t, find.text('Đã hủy'));
    expect(card(4), findsOneWidget);
    expect(find.text('Học viên hủy: Ban viec'), findsOneWidget);
  });
}
