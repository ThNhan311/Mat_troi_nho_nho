import 'package:fitcenter/screens/schedule_page.dart';
import 'package:fitcenter/screens/trainer_detail_page.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/services/booking_state.dart';
import 'package:fitcenter/services/vietnam_time.dart';
import 'package:fitcenter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overview_test.dart' show login;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'widget_test.dart' as f;

final today = vietnamDate(DateTime.now().toUtc());

const otherId = '70000000-0000-0000-0000-000000000007';

Future<BookingState> show(
  WidgetTester t,
  http.Response Function() slots, {
  bool second = false,
}) async {
  await t.binding.setSurfaceSize(const Size(500, 1600));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final api = ApiClient(
    expectedRole: 'MEMBER',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/login')) return f.json(login);
      // The second trainer never has anything free.
      if (path.endsWith('/$otherId/slots')) return f.json([]);
      if (path.endsWith('/slots')) return slots();
      if (path.endsWith('/trainers/${f.ptId}')) {
        return f.json({'id': f.ptId, 'fullName': 'Fixture PT'});
      }
      if (path.endsWith('/trainers')) {
        return f.json([
          {'id': f.ptId, 'fullName': 'Fixture PT'},
          if (second) {'id': otherId, 'fullName': 'Busy PT'},
        ]);
      }
      return f.json([]);
    }),
  );
  addTearDown(api.dispose);
  await api.login('fixture', 'test');
  final state = BookingState(BookingService(api));
  addTearDown(state.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AnimatedBuilder(
          animation: state,
          builder: (_, _) => SchedulePage(state: state),
        ),
      ),
    ),
  );
  await state.refresh();
  await t.pumpAndSettle();
  state.selectDay(today);
  await t.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('a day with no free slot shows its record and the note', (
    t,
  ) async {
    await show(t, () => f.json([]));
    expect(find.byKey(const Key('day-summary')), findsOneWidget);
    expect(
      find.text('Hôm nay bạn chưa check-in và chưa có buổi PT.'),
      findsOneWidget,
    );
    expect(find.text('Hôm nay không có khung giờ khả dụng.'), findsOneWidget);
    expect(find.text('1. Chọn huấn luyện viên'), findsNothing);
  });

  testWidgets('a day with a free slot keeps the booking steps', (t) async {
    final start = DateTime.utc(today.year, today.month, today.day, 15);
    await show(
      t,
      () => f.json([
        {
          ...f.slot(),
          'startAt': start.toIso8601String(),
          'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
        },
      ]),
    );
    expect(find.textContaining('không có khung giờ'), findsNothing);
    expect(find.text('1. Chọn huấn luyện viên'), findsOneWidget);
  });

  testWidgets('only trainers free on the chosen day are offered', (t) async {
    final start = DateTime.utc(today.year, today.month, today.day, 15);
    await show(
      t,
      () => f.json([
        {
          ...f.slot(),
          'startAt': start.toIso8601String(),
          'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
        },
      ]),
      second: true,
    );
    expect(find.text('Fixture PT'), findsOneWidget);
    expect(find.text('Busy PT'), findsNothing);
  });

  testWidgets('a trainer profile opens without choosing them', (t) async {
    final start = DateTime.utc(today.year, today.month, today.day, 15);
    final state = await show(
      t,
      () => f.json([
        {
          ...f.slot(),
          'startAt': start.toIso8601String(),
          'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
        },
      ]),
      second: true,
    );
    await t.tap(find.byKey(const ValueKey('trainer-profile-${f.ptId}')));
    await t.pumpAndSettle();
    expect(find.byType(TrainerDetailPage), findsOneWidget);
    expect(find.text('Lịch trống sắp tới'), findsOneWidget);
    expect(state.trainerId, isNull);

    // The profile button takes them back and chooses the trainer.
    await t.tap(find.text('Chọn lịch tập với PT'));
    await t.pumpAndSettle();
    expect(find.byType(TrainerDetailPage), findsNothing);
    expect(state.trainerId, f.ptId);
  });

  testWidgets('an unreadable schedule never claims there are no slots', (
    t,
  ) async {
    await show(
      t,
      () => f.json({
        'error': {'code': 'OFFLINE', 'message': 'no'},
      }, 503),
    );
    expect(find.textContaining('không có khung giờ'), findsNothing);
    expect(find.text('1. Chọn huấn luyện viên'), findsOneWidget);
  });
}
