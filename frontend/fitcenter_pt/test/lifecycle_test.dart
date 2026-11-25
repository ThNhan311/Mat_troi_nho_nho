import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_pt/services/api_client.dart';
import 'package:fitcenter_pt/services/booking_service.dart';
import 'package:fitcenter_pt/services/booking_models.dart';

import 'widget_test.dart' as f;

const replacement = '50000000-0000-0000-0000-000000000005';
Map<String, dynamic> cancelled() => {
  ...f.booking(),
  'status': 'CANCELLED',
  'cancelledBy': 'PT',
  'cancelReason': 'PT unavailable',
  'cancelledAt': '2030-01-01T00:00:00Z',
};
Map<String, dynamic> completed() => {
  ...f.booking(),
  'status': 'COMPLETED',
  'completedAt': '2030-01-02T04:30:00Z',
};
Map<String, dynamic> check([bool eligible = false]) => {
  'eligible': eligible,
  'checkedAt': '2030-01-01T00:00:00Z',
  'reasonCodes': eligible ? [] : ['SESSION_NOT_STARTED'],
};
ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      expectedRole: 'PT',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login'))
          return f.json({
            'role': 'PT',
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
          });
        return handler(r);
      }),
    );
Future<void> tapKey(WidgetTester t, String key) async {
  final finder = find.byKey(ValueKey(key));
  await t.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  test('PATCH accepts replacement UUID and DELETE 204 uses that ID', () async {
    final methods = <String>[];
    final api = client((r) async {
      methods.add(r.method);
      if (r.method == 'PATCH') {
        expect(r.url.path, endsWith('/${f.slotId}'));
        expect(jsonDecode(r.body)['endAt'], '2030-01-02T06:30:00.000Z');
        return f.json({
          ...f.slot(),
          'id': replacement,
          'startAt': '2030-01-02T05:00:00Z',
          'endAt': '2030-01-02T06:30:00Z',
        });
      }
      expect(r.url.path, endsWith('/$replacement'));
      return http.Response('', 204);
    });
    addTearDown(api.dispose);
    await api.login('fixture@example.invalid', 'test-only');
    final service = BookingService(api);
    final next = await service.edit(
      Slot.fromJson(f.slot()),
      DateTime.utc(2030, 1, 2, 5),
    );
    expect(next.id, replacement);
    await service.remove(next);
    expect(methods, ['PATCH', 'DELETE']);
  });
  test('PT cancel reason required and terminal metadata mapped', () async {
    var writes = 0;
    final api = client((r) async {
      writes++;
      expect(jsonDecode(r.body), {'reason': 'PT unavailable'});
      return f.json(cancelled());
    });
    addTearDown(api.dispose);
    await api.login('fixture@example.invalid', 'test-only');
    final service = BookingService(api);
    final b = Booking.fromJson(f.booking());
    await expectLater(service.cancel(b, '  '), throwsA(isA<ApiError>()));
    expect(writes, 0);
    final next = await service.cancel(b, 'PT unavailable');
    expect(next.cancelReason, 'PT unavailable');
    expect(next.cancelledBy, 'PT');
    expect(writes, 1);
  });
  test('complete does not require eligibility, checks completedAt', () async {
    var writes = 0;
    final api = client((r) async {
      writes++;
      expect(r.url.path, endsWith('/${f.bookingId}/complete'));
      return f.json(completed());
    });
    addTearDown(api.dispose);
    await api.login('fixture@example.invalid', 'test-only');
    final next = await BookingService(api)
        .complete(Booking.fromJson(f.booking()));
    expect(next.completedAt, DateTime.utc(2030, 1, 2, 4, 30));
    expect(writes, 1);
  });
  test(
    'eligibility false HTTP200 is data, fresh GET returns changed result',
    () async {
      var reads = 0;
      final api = client((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, endsWith('/service-eligibility'));
        return f.json(check(reads++ > 0));
      });
      addTearDown(api.dispose);
      await api.login('fixture@example.invalid', 'test-only');
      final service = BookingService(api), b = Booking.fromJson(f.booking());
      final first = await service.eligibility(b);
      expect(first.eligible, false);
      expect(first.reasonCodes, ['SESSION_NOT_STARTED']);
      expect(first.checkedAt.isUtc, true);
      expect((await service.eligibility(b)).eligible, true);
      expect(reads, 2);
    },
  );
  test(
    'eligibility rejects inconsistent payload and preserves unknown reason',
    () {
      expect(
        () => ServiceEligibility.fromJson({...check(), 'eligible': true}),
        throwsA(isA<ApiError>()),
      );
      expect(eligibilityReason('NEW_CODE'), contains('NEW_CODE'));
    },
  );
  for (final method in ['PATCH', 'DELETE', 'cancel', 'complete']) {
    for (final network in [false, true]) {
      test(
        '$method ${network ? "network" : "409"} has no write replay',
        () async {
          var writes = 0;
          final api = client((r) async {
            writes++;
            if (network) throw http.ClientException('offline');
            return f.json({
              'error': {
                'code': 'ERR_BOOKING_NOT_CONFIRMED',
                'message': 'Conflict',
                'correlationId': 'fixture-correlation',
              },
            }, 409);
          });
          addTearDown(api.dispose);
          await api.login('fixture@example.invalid', 'test-only');
          final service = BookingService(api),
              slot = Slot.fromJson(f.slot()),
              b = Booking.fromJson(f.booking());
          Future<void> action() async {
            switch (method) {
              case 'PATCH':
                await service.edit(slot, DateTime.utc(2030, 1, 2, 5));
              case 'DELETE':
                await service.remove(slot);
              case 'cancel':
                await service.cancel(b, 'PT unavailable');
              case 'complete':
                await service.complete(b);
            }
          }

          await expectLater(
            action(),
            throwsA(
              isA<ApiError>().having(
                (e) => network ? e.outcomeUnknown : e.status == 409,
                'controlled',
                true,
              ),
            ),
          );
          expect(writes, 1);
        },
      );
    }
  }
  testWidgets(
    'edit replacement then DELETE uses current ID, reloads DISABLED',
    (t) async {
      var edited = false, removed = false;
      final writes = <String>[];
      final api = client((r) async {
        if (r.method == 'PATCH') {
          writes.add(r.method);
          edited = true;
          return f.json({
            ...f.slot(),
            'id': replacement,
            'startAt': '2030-01-02T05:00:00Z',
            'endAt': '2030-01-02T06:30:00Z',
          });
        }
        if (r.method == 'DELETE') {
          expect(r.url.path, endsWith('/$replacement'));
          writes.add(r.method);
          removed = true;
          return http.Response('', 204);
        }
        if (r.url.path.endsWith('/slots'))
          return f.json([
            if (!removed)
              (edited
                  ? {
                      ...f.slot(),
                      'id': replacement,
                      'startAt': '2030-01-02T05:00:00Z',
                      'endAt': '2030-01-02T06:30:00Z',
                    }
                  : f.slot()),
          ]);
        return f.json([]);
      });
      addTearDown(api.dispose);
      await f.login(t, api);
      await tapKey(t, 'edit-${f.slotId}');
      await t.enterText(
        find.byKey(const Key('action-input')),
        '2030-01-02 12:00',
      );
      await t.tap(find.byKey(const Key('submit-input')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit-${f.slotId}')), findsNothing);
      await tapKey(t, 'delete-$replacement');
      await t.tap(find.byKey(const Key('confirm-action')));
      await t.pumpAndSettle();
      expect(writes, ['PATCH', 'DELETE']);
      expect(find.byKey(const ValueKey('delete-$replacement')), findsNothing);
    },
  );
  testWidgets(
    'reason dialog rejects blank then PT cancellation shows server reason',
    (t) async {
      var done = false, writes = 0;
      final api = client((r) async {
        if (r.method == 'POST') {
          writes++;
          done = true;
          return f.json(cancelled());
        }
        return f.json(
          r.url.path.endsWith('/bookings')
              ? [done ? cancelled() : f.booking()]
              : [],
        );
      });
      addTearDown(api.dispose);
      await f.login(t, api);
      await tapKey(t, 'cancel-${f.bookingId}');
      await t.enterText(find.byKey(const Key('action-input')), '  ');
      await t.tap(find.byKey(const Key('submit-input')));
      await t.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Không được để trống.'), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('action-input')),
        'PT unavailable',
      );
      await t.tap(find.byKey(const Key('submit-input')));
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Lý do: PT unavailable'), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-${f.bookingId}')), findsNothing);
    },
  );
  testWidgets(
    'false eligibility translated and timestamped, then complete independent',
    (t) async {
      var reads = 0, done = false;
      final api = client((r) async {
        if (r.url.path.endsWith('/service-eligibility')) {
          reads++;
          return f.json(check());
        }
        if (r.method == 'POST') {
          done = true;
          return f.json(completed());
        }
        return f.json(
          r.url.path.endsWith('/bookings')
              ? [done ? completed() : f.booking()]
              : [],
        );
      });
      addTearDown(api.dispose);
      await f.login(t, api);
      await tapKey(t, 'eligibility-${f.bookingId}');
      expect(find.text('Chưa đủ điều kiện'), findsOneWidget);
      expect(find.textContaining('Chưa đến giờ buổi tập.'), findsOneWidget);
      expect(
        find.textContaining('UTC: 2030-01-01T00:00:00.000Z'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('close-eligibility')));
      await t.pumpAndSettle();
      await tapKey(t, 'eligibility-${f.bookingId}');
      expect(reads, 2);
      await t.tap(find.byKey(const Key('close-eligibility')));
      await t.pumpAndSettle();
      await tapKey(t, 'complete-${f.bookingId}');
      await t.tap(find.byKey(const Key('confirm-action')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('complete-${f.bookingId}')),
        findsNothing,
      );
      expect(find.textContaining('COMPLETED'), findsWidgets);
    },
  );

  for (final network in [false, true]) {
    testWidgets(
      'complete ${network ? "network" : "409"} keeps state and blocks ambiguous retry',
      (t) async {
        var writes = 0;
        final api = client((r) async {
          if (r.method == 'POST') {
            writes++;
            if (network) throw http.ClientException('offline');
            return f.json({
              'error': {
                'code': 'ERR_BOOKING_NOT_ENDED',
                'message': 'Not ended',
                'correlationId': 'fixture-correlation',
              },
            }, 409);
          }
          return f.json(r.url.path.endsWith('/bookings') ? [f.booking()] : []);
        });
        addTearDown(api.dispose);
        await f.login(t, api);
        await tapKey(t, 'complete-${f.bookingId}');
        await t.tap(find.byKey(const Key('confirm-action')));
        await t.pumpAndSettle();
        expect(writes, 1);
        expect(find.byKey(const Key('success')), findsNothing);
        await t.scrollUntilVisible(
          find.byKey(const Key('api-error')),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pumpAndSettle();
        expect(
          find.textContaining(
            network ? 'NETWORK_ERROR' : 'ERR_BOOKING_NOT_ENDED',
          ),
          findsOneWidget,
        );
        if (network) {
          await t.scrollUntilVisible(
            find.byKey(const ValueKey('complete-${f.bookingId}')),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const ValueKey('complete-${f.bookingId}')),
                )
                .onPressed,
            isNull,
          );
        }
      },
    );
  }
}
