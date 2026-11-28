import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/main.dart' as app;
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/services/booking_state.dart';
import 'package:fitcenter/services/vietnam_time.dart';

import 'widget_test.dart' as f;

Future<void> enter(WidgetTester t, ApiClient api) async {
  await t.pumpWidget(app.FitCenterApp(api: api));
  await t.enterText(
    find.byKey(const Key('email')),
    'synthetic@example.invalid',
  );
  await t.enterText(find.byKey(const Key('password')), 'test-only');
  await t.tap(find.byKey(const Key('login')));
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  for (var i = 0; i < 8 && finder.hitTestable().evaluate().isEmpty; i++) {
    await t.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, -300),
    );
    await t.pumpAndSettle();
  }
  await t.tap(finder);
  await t.pumpAndSettle();
}

Map<String, dynamic> auth() => {
  'role': 'MEMBER',
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
};
void main() {
  testWidgets(
    'original Home -> PT detail -> calendar -> 201 booking -> original history cancel',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var booked = false, cancelled = false, writes = 0;
      final day = vietnamDate(DateTime.now().toUtc());
      final start = DateTime.utc(day.year, day.month, day.day, 15);
      final slot = {
        ...f.slot(),
        'startAt': start.toIso8601String(),
        'endAt': start.add(const Duration(minutes: 90)).toIso8601String(),
      };
      final booking = {
        ...f.booking(),
        'startAt': slot['startAt'],
        'endAt': slot['endAt'],
      };
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.method == 'POST') {
            writes++;
            if (r.url.path.endsWith('/cancel')) {
              expect(r.url.path, '/api/v1/bookings/${f.bookingId}/cancel');
              cancelled = true;
              return f.json({
                ...booking,
                'status': 'CANCELLED',
                'cancelledBy': 'MEMBER',
                'cancelledAt': DateTime.now().toUtc().toIso8601String(),
              });
            }
            expect(jsonDecode(r.body), {'ptId': f.ptId, 'slotId': f.slotId});
            booked = true;
            return f.json(booking, 201);
          }
          if (r.url.path.endsWith('/bookings/me'))
            return f.json(
              booked
                  ? [
                      {
                        ...booking,
                        'status': cancelled ? 'CANCELLED' : 'CONFIRMED',
                      },
                    ]
                  : [],
            );
          if (r.url.path.endsWith('/slots'))
            return f.json(booked && !cancelled ? [] : [slot]);
          if (r.url.path.endsWith('/${f.ptId}'))
            return f.json({
              'id': f.ptId,
              'fullName': 'Fixture PT',
              'bio': 'Server profile',
            });
          return f.json([
            {'id': f.ptId, 'fullName': 'Fixture PT'},
          ]);
        }),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      expect(find.text('YOUR FITNESS JOURNEY'), findsOneWidget);
      await tap(t, find.text('PT').last);
      await tap(t, find.byKey(const ValueKey('trainer-${f.ptId}')));
      expect(find.text('Server profile'), findsOneWidget);
      await tap(t, find.text('Chọn lịch tập với PT'));
      await tap(
        t,
        find.byKey(ValueKey('day-${day.year}-${day.month}-${day.day}')),
      );
      await tap(t, find.byKey(const ValueKey('slot-${f.slotId}')));
      await tap(t, find.text('Xác nhận đặt lịch').first);
      await tap(
        t,
        find.widgetWithText(ElevatedButton, 'Xác nhận đặt lịch').last,
      );
      expect(writes, 1);
      // A one-line pop-up, with no booking code.
      expect(find.byKey(const Key('success')), findsOneWidget);
      expect(find.text('Đặt lịch thành công'), findsOneWidget);
      expect(find.textContaining('Mã đặt lịch'), findsNothing);
      await tap(t, find.byKey(const Key('success-close')));
      expect(find.byKey(const Key('success')), findsNothing);
      await tap(t, find.text('Cá nhân').last);
      await tap(t, find.text('Lịch sử đặt lịch'));
      expect(
        find.byKey(const ValueKey('history-${f.bookingId}')),
        findsOneWidget,
      );
      await tap(t, find.text('Hủy lịch'));
      expect(writes, 1);
      await tap(t, find.text('Hủy lịch').last);
      expect(writes, 2);
      expect(find.text('Đã hủy'), findsOneWidget);
    },
  );
  for (final code in [
    'ERR_CANCELLATION_DEADLINE',
    'BOOKING_POLICY_NOT_FOUND',
    'NETWORK_ERROR',
  ])
    test('original state preserves $code and never replays cancel', () async {
      var writes = 0;
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.method == 'POST') {
            writes++;
            if (code == 'NETWORK_ERROR') throw http.ClientException('offline');
            return f.json({
              'error': {
                'code': code,
                'message': 'Denied',
                'correlationId': 'original-ui-test',
              },
            }, code == 'BOOKING_POLICY_NOT_FOUND' ? 404 : 409);
          }
          return f.json(
            r.url.path.endsWith('/bookings/me')
                ? [f.booking()]
                : [
                    {'id': f.ptId, 'fullName': 'Fixture PT'},
                  ],
          );
        }),
      );
      addTearDown(api.dispose);
      await api.login('test', 'test');
      final state = BookingState(BookingService(api));
      addTearDown(state.dispose);
      await state.refresh();
      await state.act(() => state.cancel(f.bookingId));
      expect(writes, 1);
      expect(state.bookings.single.status, 'CONFIRMED');
      expect(state.message, isNull);
      expect(state.error, contains(code));
      if (code == 'NETWORK_ERROR') expect(state.needsReconciliation, isTrue);
    });
  testWidgets(
    'logout during detail read discards old account routes and response',
    (t) async {
      final pending = Completer<http.Response>();
      var asked = false;
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.url.path.endsWith('/${f.ptId}')) {
            asked = true;
            return pending.future;
          }
          return f.json(
            r.url.path.endsWith('/bookings/me')
                ? []
                : [
                    {'id': f.ptId, 'fullName': 'Old PT'},
                  ],
          );
        }),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      await tap(t, find.text('PT').last);
      await t.ensureVisible(find.byKey(const ValueKey('trainer-${f.ptId}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('trainer-${f.ptId}')));
      await t.pump();
      // The detail read must really be waiting, or this proves nothing.
      expect(asked, isTrue);
      api.logout();
      await t.pumpAndSettle();
      pending.complete(
        f.json({'id': f.ptId, 'fullName': 'Stale private name'}),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('login')), findsOneWidget);
      expect(find.text('Stale private name'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'original Home shows read failure and no fake operational profile',
    (t) async {
      final api = ApiClient(
        expectedRole: 'MEMBER',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient(
          (r) async => r.url.path.endsWith('/login')
              ? f.json(auth())
              : f.json({
                  'error': {'code': 'OFFLINE', 'message': 'Unavailable'},
                }, 503),
        ),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      expect(find.textContaining('OFFLINE'), findsOneWidget);
      await tap(t, find.text('Cá nhân').last);
      expect(find.text('Nguyễn Văn Nam'), findsNothing);
      expect(find.text('Gói cao cấp'), findsNothing);
    },
  );
  testWidgets('logout removes an already open original confirmation dialog', (
    t,
  ) async {
    final api = ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return f.json(auth());
        return f.json(
          r.url.path.endsWith('/bookings/me')
              ? [f.booking()]
              : [
                  {'id': f.ptId, 'fullName': 'Fixture PT'},
                ],
        );
      }),
    );
    addTearDown(api.dispose);
    await enter(t, api);
    await tap(t, find.text('Cá nhân').last);
    await tap(t, find.text('Lịch sử đặt lịch'));
    await tap(t, find.text('Hủy lịch'));
    expect(find.byType(AlertDialog), findsOneWidget);
    api.logout();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('login')), findsOneWidget);
    expect(find.textContaining(f.bookingId), findsNothing);
  });
}
