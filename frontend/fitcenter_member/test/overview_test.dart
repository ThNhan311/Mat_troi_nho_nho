import 'package:fitcenter/main.dart' as app;
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/services/booking_state.dart';
import 'package:fitcenter/services/membership_service.dart';
import 'package:fitcenter/services/vietnam_time.dart';
import 'package:fitcenter/theme/app_theme.dart';
import 'package:fitcenter/widgets/overview_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'widget_test.dart' as f;
import 'pull.dart';

String date(int daysFromToday) =>
    vietnamDate(DateTime.now().toUtc())
        .add(Duration(days: daysFromToday))
        .toIso8601String()
        .substring(0, 10);

Map<String, dynamic> membership(
  String name,
  String status,
  int start,
  int end,
) => {
  'id': f.memberId,
  'planId': f.ptId,
  'planName': name,
  'status': status,
  'startDate': date(start),
  'endDate': date(end),
};

Future<BookingState> show(WidgetTester t, MockClient client) async {
  final api = ApiClient(
    expectedRole: 'MEMBER',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: client,
  );
  addTearDown(api.dispose);
  await api.login('fixture', 'test');
  final state = BookingState(BookingService(api));
  addTearDown(state.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: state,
            builder: (_, _) => OverviewSection(
              state: state,
              active: true,
              onOpenSchedule: () {},
              onOpenMembership: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await state.refresh();
  await t.pumpAndSettle();
  return state;
}

const login = {'role': 'MEMBER', 'accessToken': 'a', 'refreshToken': 'b'};

void main() {
  test('a usable package wins over expired and cancelled ones', () {
    final rows = [
      membership('Old', 'EXPIRED', -60, -30),
      membership('Cancelled', 'CANCELLED', -1, 90),
      membership('Later', 'ACTIVE', 10, 40),
      membership('Now', 'ACTIVE', -5, 25),
    ].map(Membership.fromJson).toList();
    final today = vietnamDate(DateTime.now().toUtc());
    expect(mainMembership(rows, today)!.planName, 'Now');
    expect(mainMembership([rows[1]], today), isNull);
  });

  testWidgets('shows server package, next session and check-ins', (t) async {
    final start = DateTime.now().toUtc().add(const Duration(days: 2));
    var rangeKeys = <String>[];
    await show(
      t,
      MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/memberships/me')) {
          return f.json([membership('Fixture plan', 'ACTIVE', -20, 10)]);
        }
        if (path.endsWith('/attendance/me')) {
          rangeKeys = r.url.queryParameters.keys.toList();
          return f.json([
            {'checkedInAt': DateTime.now().toUtc().toIso8601String()},
          ]);
        }
        if (path.endsWith('/bookings/me')) {
          return f.json([
            {
              ...f.booking(),
              'startAt': start.toIso8601String(),
              'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
            },
          ]);
        }
        return f.json([
          {'id': f.ptId, 'fullName': 'Fixture PT'},
        ]);
      }),
    );
    expect(rangeKeys, containsAll(['from', 'to']));
    expect(find.textContaining('Fixture plan'), findsOneWidget);
    expect(find.textContaining('Còn 10 ngày'), findsOneWidget);
    expect(find.text('Với Fixture PT'), findsOneWidget);
    expect(find.text('1 lần'), findsOneWidget);
    expect(find.text('1 buổi'), findsOneWidget);
  });

  testWidgets('pulling the home page down reloads it', (t) async {
    var bookings = 0, memberships = 0;
    final api = ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/bookings/me')) bookings++;
        if (path.endsWith('/memberships/me')) memberships++;
        return f.json([]);
      }),
    );
    addTearDown(api.dispose);
    await api.login('fixture', 'test');
    await t.pumpWidget(app.FitCenterApp(api: api));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('home-logo')), findsOneWidget);
    expect(find.byKey(const Key('refresh')), findsNothing);
    final before = (bookings, memberships);
    await t.fling(find.text('Xin chào hội viên!'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    // The booking list, plus the calendar's read of the whole month.
    expect(bookings, before.$1 + 2);
    expect(memberships, before.$2 + 1);
    // No page keeps a reload button; each one reloads when pulled.
    for (final tab in ['Lịch tập', 'Gói hội viên', 'PT', 'Cá nhân']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.refresh), findsNothing, reason: tab);
      if (tab == 'Cá nhân') continue;
      final count = bookings + memberships;
      await pullToReload(t);
      expect(bookings + memberships, greaterThan(count), reason: tab);
    }
  });

  testWidgets('the profile tab shows a short member code', (t) async {
    final api = ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/profile/me')) {
          return f.json({'profileId': f.memberId, 'fullName': 'Fixture'});
        }
        return f.json([]);
      }),
    );
    addTearDown(api.dispose);
    await api.login('fixture', 'test');
    await t.pumpWidget(app.FitCenterApp(api: api));
    await t.pumpAndSettle();
    await t.tap(find.text('Cá nhân').last);
    await t.pumpAndSettle();
    expect(
      find.text('Mã hội viên: ${f.memberId.substring(0, 8).toUpperCase()}'),
      findsOneWidget,
    );
    expect(find.textContaining(f.memberId), findsNothing);
    // The card shows the name, with the role in small text under it.
    expect(find.text('Fixture'), findsOneWidget);
    expect(find.text('Hội viên'), findsOneWidget);
  });

  testWidgets('empty account says so and offers booking', (t) async {
    await show(
      t,
      MockClient(
        (r) async => f.json(r.url.path.endsWith('/login') ? login : []),
      ),
    );
    expect(find.text('Chưa đăng ký gói'), findsOneWidget);
    expect(find.text('Chưa có lịch sắp tới'), findsOneWidget);
    expect(find.text('0 lần'), findsOneWidget);
  });

  testWidgets('a failed read never shows zero and keeps the session', (
    t,
  ) async {
    var refreshes = 0;
    final state = await show(
      t,
      MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/refresh')) refreshes++;
        if (path.endsWith('/memberships/me') ||
            path.endsWith('/attendance/me')) {
          return f.json({
            'error': {'code': 'UNAUTHORIZED', 'message': 'no'},
          }, 401);
        }
        return f.json([]);
      }),
    );
    expect(find.text('Chưa tải được gói tập'), findsOneWidget);
    expect(find.text('Chưa tải được'), findsOneWidget);
    expect(find.text('0 lần'), findsNothing);
    expect(refreshes, 0);
    expect(state.service.api.authenticated, isTrue);
  });
}
