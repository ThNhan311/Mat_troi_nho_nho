import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fitcenter_pt/services/api_client.dart';
import 'package:fitcenter_pt/services/vietnam_time.dart';
import 'package:fitcenter_pt/widgets/start_time_dialog.dart';

import 'original_ui_test.dart' show auth, enter, tap;
import 'widget_test.dart' as f;

const freeId = '60000000-0000-0000-0000-000000000006';

/// Tomorrow in Vietnam: one booked slot at 08:00 and one free one at 11:00.
final today = vietnamDate(DateTime.now().toUtc());
final tomorrow = today.add(const Duration(days: 1));
DateTime at(int hour) => tomorrow.add(Duration(hours: hour - 7));

Map<String, dynamic> when(Map<String, dynamic> row, int hour) => {
  ...row,
  'startAt': at(hour).toIso8601String(),
  'endAt': at(hour).add(const Duration(minutes: 90)).toIso8601String(),
};

Future<void> open(WidgetTester t) async {
  final api = ApiClient(
    expectedRole: 'PT',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/login')) return f.json(auth());
      if (path.endsWith('/pt/booked-members')) {
        return f.json([
          {
            'memberId': f.memberId,
            'fullName': 'Tran Thi Hoa',
            'phone': '0901234567',
            'gender': 'FEMALE',
          },
        ]);
      }
      if (path.endsWith('/pt/bookings')) {
        return f.json([when(f.booking(), 8)]);
      }
      if (path.endsWith('/pt/slots')) {
        return f.json([
          when(f.slot('BOOKED'), 8),
          when({...f.slot(), 'id': freeId}, 11),
        ]);
      }
      return f.json([]);
    }),
  );
  addTearDown(api.dispose);
  await enter(t, api);
  await tap(t, find.text('Lịch làm').last);
  if (tomorrow.month != today.month) {
    await tap(t, find.byKey(const Key('next-month')));
  }
}

Finder day(DateTime date) =>
    find.byKey(ValueKey('day-${date.year}-${date.month}-${date.day}'));

/// The dots drawn under one day.
int dots(WidgetTester t, DateTime date) => t
    .widgetList(
      find.descendant(of: day(date), matching: find.byType(Container)),
    )
    .where(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('mark-'),
    )
    .length;

TimeWheel wheel(WidgetTester t, String kind) =>
    t.widget<TimeWheel>(find.byKey(Key('$kind-wheel')));

/// Drags a wheel on by whole rows.
Future<void> roll(WidgetTester t, String kind, int rows) async {
  await t.drag(
    find.byKey(Key('$kind-wheel')),
    Offset(0, -TimeWheel.rowHeight * rows),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the calendar marks a day and lists what is on it', (t) async {
    await open(t);
    // Free and booked.
    expect(dots(t, tomorrow), 2);
    expect(find.text('Tất cả khung giờ'), findsOneWidget);

    await tap(t, day(tomorrow));
    expect(find.textContaining('• 2 khung giờ'), findsOneWidget);
    expect(find.text('08:00 - 09:30'), findsOneWidget);
    expect(find.text('11:00 - 12:30'), findsOneWidget);
    // The booked slot says who booked it and how to reach them.
    expect(find.text('Tran Thi Hoa'), findsOneWidget);
    expect(find.text('Nữ'), findsOneWidget);
    expect(find.text('Mã hội viên: 40000000'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);

    await tap(t, find.byKey(const Key('all-slots')));
    expect(find.text('Tất cả khung giờ'), findsOneWidget);
  });

  testWidgets('a new slot starts on the chosen day', (t) async {
    await open(t);
    await tap(t, day(tomorrow));
    await tap(t, find.byKey(const Key('create-slot')));
    final two = (int n) => n.toString().padLeft(2, '0');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          '${two(tomorrow.day)}/${two(tomorrow.month)}/${tomorrow.year}',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('only the start is chosen; the end follows 90 minutes later', (
    t,
  ) async {
    await open(t);
    await tap(t, day(tomorrow));
    await tap(t, find.byKey(const Key('create-slot')));
    expect(find.textContaining('tự tính sau giờ bắt đầu 90 phút'), findsOne);
    await tap(t, find.text('Lưu'));
    expect(find.text('Vui lòng chọn giờ bắt đầu.'), findsOneWidget);

    await tap(t, find.byKey(const Key('slot-start-time')));
    // A later day offers the whole clock, in 24 hours, starting at 08:00.
    expect(wheel(t, 'hour').values, List.generate(24, (i) => i));
    expect(wheel(t, 'hour').selected, 8);
    expect(wheel(t, 'minute').selected, 0);
    expect(find.textContaining('AM'), findsNothing);
    // Roll six hours and six steps of five minutes.
    await roll(t, 'hour', 6);
    await roll(t, 'minute', 6);
    await tap(t, find.byKey(const Key('time-confirm')));
    expect(find.text('Giờ kết thúc: 16:00 (90 phút)'), findsOneWidget);
  });

  testWidgets('today offers only the times still ahead', (t) async {
    await open(t);
    if (tomorrow.month != today.month) {
      await tap(t, find.byKey(const Key('previous-month')));
    }
    await tap(t, find.byKey(const Key('create-slot')));
    await tap(t, find.byKey(const Key('slot-start-time')));
    final now = vietnamClock(DateTime.now().toUtc());
    final hour = int.parse(now.substring(0, 2));
    // Near midnight there may be nothing left at all.
    if (find.byType(TimeWheel).evaluate().isEmpty) {
      expect(find.textContaining('không còn giờ nào'), findsOneWidget);
    } else {
      expect(wheel(t, 'hour').values.every((h) => h >= hour), isTrue);
      final first =
          '${twoDigits(wheel(t, 'hour').selected)}:'
          '${twoDigits(wheel(t, 'minute').selected)}';
      expect(first.compareTo(now), greaterThan(0));
    }
  });

  testWidgets('the date picker is in Vietnamese', (t) async {
    await open(t);
    await tap(t, find.byKey(const Key('create-slot')));
    await tap(t, find.byIcon(Icons.calendar_month).last);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Hủy'), findsWidgets);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Select date'), findsNothing);
  });

  testWidgets('an empty day says so and still allows creating', (t) async {
    await open(t);
    final empty = DateTime.utc(tomorrow.year, tomorrow.month, 1) == tomorrow
        ? tomorrow.add(const Duration(days: 1))
        : DateTime.utc(tomorrow.year, tomorrow.month, 1);
    await tap(t, day(empty));
    expect(find.textContaining('chưa có khung giờ làm.'), findsOneWidget);
    expect(find.byKey(const Key('create-slot')), findsOneWidget);
  });
}
