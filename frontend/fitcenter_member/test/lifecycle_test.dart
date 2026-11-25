import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/booking_service.dart';
import 'package:fitcenter/services/booking_models.dart';

import 'widget_test.dart' as f;

Map<String, dynamic> cancelled() => {
  ...f.booking(),
  'status': 'CANCELLED',
  'cancelledBy': 'MEMBER',
  'cancelledAt': '2030-01-01T00:00:00Z',
};
ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login'))
          return f.json({
            'role': 'MEMBER',
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
          });
        return handler(r);
      }),
    );
Future<void> reachCancel(WidgetTester t) async {
  await t.scrollUntilVisible(
    find.byKey(const ValueKey('cancel-${f.bookingId}')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await t.tap(find.byKey(const ValueKey('cancel-${f.bookingId}')));
  await t.pumpAndSettle();
}

void main() {
  test('cancel uses booking id, no slot lookup, validates metadata', () async {
    final api = client((r) async {
      expect(r.url.path, '/api/v1/bookings/${f.bookingId}/cancel');
      expect(r.method, 'POST');
      expect(r.body, isEmpty);
      return f.json(cancelled());
    });
    addTearDown(api.dispose);
    await api.login('fixture@example.invalid', 'test-only');
    final b = await BookingService(api).cancel(Booking.fromJson(f.booking()));
    expect(b.id, f.bookingId);
    expect(b.cancelledBy, 'MEMBER');
    expect(b.cancelledAt, DateTime.utc(2030));
  });
  test(
    'wrong booking success payload is ambiguous, never a local transition',
    () async {
      final api = client((_) async => f.json({...cancelled(), 'id': f.slotId}));
      addTearDown(api.dispose);
      await api.login('fixture@example.invalid', 'test-only');
      await expectLater(
        BookingService(api).cancel(Booking.fromJson(f.booking())),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    },
  );
  testWidgets('cancel confirmation can abort without write', (t) async {
    var writes = 0;
    final api = client((r) async {
      if (r.method == 'POST') writes++;
      return f.json(r.url.path.endsWith('/bookings/me') ? [f.booking()] : []);
    });
    addTearDown(api.dispose);
    await f.login(t, api);
    await reachCancel(t);
    expect(writes, 0);
    await t.tap(find.text('Quay lại'));
    await t.pumpAndSettle();
    expect(writes, 0);
    expect(find.textContaining('CONFIRMED'), findsOneWidget);
  });
  testWidgets(
    'cancel waits for response, blocks duplicates, reloads server state',
    (t) async {
      var writes = 0, done = false;
      final gate = Completer<http.Response>();
      final api = client((r) async {
        if (r.method == 'POST') {
          writes++;
          expect(r.url.path, endsWith('/${f.bookingId}/cancel'));
          final response = await gate.future;
          done = true;
          return response;
        }
        return f.json(
          r.url.path.endsWith('/bookings/me')
              ? [done ? cancelled() : f.booking()]
              : [],
        );
      });
      addTearDown(api.dispose);
      await f.login(t, api);
      await reachCancel(t);
      await t.tap(find.byKey(const Key('confirm-cancel')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(writes, 1);
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cancel-${f.bookingId}')),
            )
            .onPressed,
        isNull,
      );
      gate.complete(f.json(cancelled()));
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(find.byKey(const ValueKey('cancel-${f.bookingId}')), findsNothing);
      expect(find.textContaining('CANCELLED'), findsWidgets);
    },
  );
  for (final code in [
    'ERR_CANCELLATION_DEADLINE',
    'BOOKING_POLICY_NOT_FOUND',
    'NETWORK_ERROR',
  ]) {
    testWidgets('cancel $code never announces success or replays', (t) async {
      var writes = 0;
      final api = client((r) async {
        if (r.method == 'POST') {
          writes++;
          if (code == 'NETWORK_ERROR') throw http.ClientException('offline');
          return f.json({
            'error': {
              'code': code,
              'message': 'Server refused',
              'correlationId': 'fixture-correlation',
            },
          }, code == 'BOOKING_POLICY_NOT_FOUND' ? 404 : 409);
        }
        return f.json(r.url.path.endsWith('/bookings/me') ? [f.booking()] : []);
      });
      addTearDown(api.dispose);
      await f.login(t, api);
      await reachCancel(t);
      await t.tap(find.byKey(const Key('confirm-cancel')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('api-error')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining(code), findsOneWidget);
      expect(find.byKey(const Key('success')), findsNothing);
      expect(writes, 1);
    });
  }
}
