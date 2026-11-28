import 'package:fitcenter/screens/schedule_page.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/services/booking_state.dart';
import 'package:fitcenter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'overview_test.dart' show login;
import 'schedule_days_test.dart' show today;
import 'widget_test.dart' as f;

Map<String, dynamic> booking(String status, String id) {
  final start = DateTime.utc(today.year, today.month, today.day, 3);
  return {
    ...f.booking(),
    'id': id,
    'status': status,
    'startAt': start.toIso8601String(),
    'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
  };
}

void main() {
  testWidgets('a day shows check-in, booked and trained dots', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final api = ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/attendance/me')) {
          return f.json([
            {
              'checkedInAt': DateTime.utc(
                today.year,
                today.month,
                today.day,
                2,
              ).toIso8601String(),
            },
          ]);
        }
        if (path.endsWith('/bookings/me')) {
          return f.json([
            booking('CONFIRMED', f.bookingId),
            booking('COMPLETED', f.memberId),
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

    final cell = find.byKey(
      ValueKey('day-${today.year}-${today.month}-${today.day}'),
    );
    final dots = t
        .widgetList<Container>(
          find.descendant(of: cell, matching: find.byType(Container)),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .map((d) => d.color)
        .toList();
    expect(dots, [
      Colors.black,
      const Color(0xFFF57C00),
      const Color(0xFF2E9E44),
    ]);
    for (final label in ['Đã check-in', 'Đã đặt trước PT', 'Đã tập với PT']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Chưa tập'), findsNothing);

    // The note sits under the whole calendar, below the legend.
    state.selectDay(today);
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(find.text('Hôm nay không có khung giờ khả dụng.')).dy,
      greaterThan(t.getBottomLeft(find.text('Đã check-in')).dy),
    );

    // The chosen day tells what happened: the scan and each session.
    expect(find.text('Check-in lúc 09:00'), findsOneWidget);
    expect(find.textContaining('Đã tập với PT '), findsOneWidget);
    expect(find.textContaining('Đã đặt trước với '), findsOneWidget);
    expect(find.textContaining('10:00 - 11:30'), findsNWidgets(2));
  });

  testWidgets('a PT session counts as checked in without a scan', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final api = ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/bookings/me')) {
          return f.json([booking('COMPLETED', f.memberId)]);
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

    final cell = find.byKey(
      ValueKey('day-${today.year}-${today.month}-${today.day}'),
    );
    final dots = t
        .widgetList<Container>(
          find.descendant(of: cell, matching: find.byType(Container)),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .map((d) => d.color)
        .toList();
    expect(dots, [Colors.black, const Color(0xFF2E9E44)]);
    for (final label in ['Đã check-in', 'Đã đặt trước PT', 'Đã tập với PT']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Chưa tập'), findsNothing);

    // The note sits under the whole calendar, below the legend.
    state.selectDay(today);
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(find.text('Hôm nay không có khung giờ khả dụng.')).dy,
      greaterThan(t.getBottomLeft(find.text('Đã check-in')).dy),
    );
  });
}
