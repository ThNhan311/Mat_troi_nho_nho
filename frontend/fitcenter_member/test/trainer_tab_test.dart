import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fitcenter/screens/trainer_list_page.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/services/booking_state.dart';
import 'package:fitcenter/widgets/trainer_photo.dart';

import 'overview_test.dart' show login;
import 'widget_test.dart' as f;

const first = '10000000-0000-0000-0000-000000000001',
    second = '10000000-0000-0000-0000-000000000002';

/// Two trainers; only the first has free sessions.
Future<(List<String>, ApiClient)> show(
  WidgetTester t, {
  int slotStatus = 200,
}) async {
  await t.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final booked = <String>[];
  final start = DateTime.now().toUtc().add(const Duration(days: 2));
  final api = ApiClient(
    expectedRole: 'MEMBER',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/login')) return f.json(login);
      if (path.endsWith('/trainers')) {
        return f.json([
          {
            'id': first,
            'fullName': 'Coach One',
            'specialization': 'Yoga, Cardio',
            'experienceSummary': '3 nam',
          },
          {
            'id': second,
            'fullName': 'Coach Two',
            'specialization': 'Boxing',
            'gender': 'FEMALE',
          },
        ]);
      }
      if (path.endsWith('/trainers/$first')) {
        return f.json({
          'id': first,
          'fullName': 'Coach One',
          'specialization': 'Yoga, Cardio',
          'experienceSummary': '3 nam',
        });
      }
      if (path.endsWith('/slots')) {
        if (slotStatus != 200) return f.json({}, slotStatus);
        return f.json([
          if (path.contains(first))
            for (var i = 1; i >= 0; i--)
              {
                'id': '2000000$i-0000-0000-0000-000000000000',
                'ptId': first,
                'startAt': start.add(Duration(days: i)).toIso8601String(),
                'endAt': start
                    .add(Duration(days: i, minutes: 90))
                    .toIso8601String(),
                'status': 'AVAILABLE',
              },
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
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) => TrainerListPage(
          state: state,
          onShowMessage: (_) {},
          onSelectTrainerForBooking: booked.add,
        ),
      ),
    ),
  );
  await state.refresh();
  await t.pumpAndSettle();
  return (booked, api);
}

void main() {
  testWidgets('cards show real free time and book straight away', (t) async {
    final (booked, _) = await show(t);
    expect(find.text('Coach One'), findsOneWidget);
    expect(find.text('Kinh nghiệm: 3 nam'), findsOneWidget);
    // A gender the server gave is shown; a missing one is not guessed.
    expect(find.text('Nữ'), findsOneWidget);
    expect(find.text('Nam'), findsNothing);
    // It sits on the name's own line, to the right of it.
    final name = t.getRect(find.text('Coach Two'));
    final gender = t.getRect(find.text('Nữ'));
    expect(gender.top, name.top);
    expect(gender.left, greaterThanOrEqualTo(name.right));
    // The picture stays a small circle.
    expect(t.getSize(find.byType(TrainerPhoto).first), const Size(68, 68));
    // Only the trainer with free sessions shows a next one.
    expect(find.text('Lịch trống gần nhất'), findsOneWidget);
    expect(find.text('Chưa có lịch trống trong thời gian tới'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('book-trainer-$first')));
    expect(booked, [first]);
  });

  testWidgets('specialty chips narrow the list', (t) async {
    await show(t);
    // The chip row scrolls sideways.
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Boxing'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Boxing'));
    await t.pumpAndSettle();
    expect(find.text('Coach Two'), findsOneWidget);
    expect(find.text('Coach One'), findsNothing);
    expect(find.text('1 huấn luyện viên'), findsOneWidget);
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await t.pumpAndSettle();
    expect(find.text('2 huấn luyện viên'), findsOneWidget);
  });

  testWidgets('the profile lists the free sessions and keeps the button', (
    t,
  ) async {
    final (booked, _) = await show(t);
    await t.tap(find.byKey(const ValueKey('trainer-$first')));
    await t.pumpAndSettle();
    expect(find.text('Lịch trống sắp tới'), findsOneWidget);
    expect(find.textContaining(' - '), findsNWidgets(2));
    // Specialties appear once, as separate tags.
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('Yoga, Cardio'), findsNothing);
    await t.tap(find.text('Chọn lịch tập với PT'));
    await t.pumpAndSettle();
    expect(booked, [first]);
  });

  // A failed read must not look like a fully booked trainer, or sign out.
  for (final status in [401, 500]) {
    testWidgets('a $status on free time says nothing about it', (t) async {
      final (_, api) = await show(t, slotStatus: status);
      expect(find.text('Coach One'), findsOneWidget);
      expect(find.textContaining('lịch trống'), findsNothing);
      expect(find.text('Lịch trống gần nhất'), findsNothing);
      expect(api.authenticated, isTrue);
    });
  }
}
