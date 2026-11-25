import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_pt/main.dart' as app;
import 'package:fitcenter_pt/services/api_client.dart';
import 'package:fitcenter_pt/services/booking_service.dart';
import 'package:fitcenter_pt/services/booking_state.dart';

import 'widget_test.dart' as f;

Map<String, dynamic> auth() => {
  'role': 'PT',
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
};
Future<void> enter(WidgetTester t, ApiClient api) async {
  await t.binding.setSurfaceSize(const Size(1024, 1600));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(app.FitCenterApp(api: api));
  await t.enterText(find.byKey(const Key('email')), 'pt@example.invalid');
  await t.enterText(find.byKey(const Key('password')), 'test-only');
  await t.tap(find.byKey(const Key('login')));
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'original Home -> Availability PATCH replacement ID -> DELETE 204',
    (t) async {
      const replacement = '50000000-0000-0000-0000-000000000005';
      var current = f.slotId, deleted = false;
      final methods = <String>[];
      final api = ApiClient(
        expectedRole: 'PT',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.method == 'PATCH') {
            methods.add('PATCH');
            expect(r.url.path.endsWith(f.slotId), isTrue);
            current = replacement;
            return f.json({...f.slot(), 'id': current});
          }
          if (r.method == 'DELETE') {
            methods.add('DELETE');
            expect(r.url.path.endsWith(replacement), isTrue);
            deleted = true;
            return http.Response('', 204);
          }
          return f.json(
            r.url.path.endsWith('/bookings')
                ? []
                : deleted
                ? []
                : [
                    {...f.slot(), 'id': current},
                  ],
          );
        }),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      expect(find.text('FitCenter PT'), findsOneWidget);
      await tap(t, find.text('Lịch làm').last);
      await tap(t, find.byKey(const ValueKey('slot-menu-${f.slotId}')));
      await tap(t, find.text('Chỉnh sửa'));
      await tap(t, find.text('Lưu'));
      expect(
        find.byKey(const ValueKey('availability-$replacement')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('availability-${f.slotId}')),
        findsNothing,
      );
      await tap(t, find.byKey(const ValueKey('slot-menu-$replacement')));
      await tap(t, find.text('Xóa'));
      await tap(t, find.text('Xóa').last);
      expect(methods, ['PATCH', 'DELETE']);
      expect(
        find.byKey(const ValueKey('availability-$replacement')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'original session reason validation and server cancellation metadata',
    (t) async {
      var writes = 0, cancelled = false;
      final next = {
        ...f.booking(),
        'status': 'CANCELLED',
        'cancelledBy': 'PT',
        'cancelledAt': '2030-01-01T00:00:00Z',
        'cancelReason': 'Server reason',
      };
      final api = ApiClient(
        expectedRole: 'PT',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.method == 'POST') {
            writes++;
            expect(r.url.path, '/api/v1/pt/bookings/${f.bookingId}/cancel');
            cancelled = true;
            return f.json(next);
          }
          return f.json(
            r.url.path.endsWith('/bookings')
                ? [cancelled ? next : f.booking()]
                : [],
          );
        }),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      await tap(t, find.text('Buổi tập').last);
      await tap(t, find.byKey(const ValueKey('session-${f.bookingId}')));
      await tap(t, find.byKey(const Key('pt-cancel')));
      await tap(t, find.byKey(const Key('submit-reason')));
      expect(writes, 0);
      expect(find.text('Bạn phải nhập lý do trước khi hủy.'), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('cancel-reason')),
        'Server reason',
      );
      await tap(t, find.byKey(const Key('submit-reason')));
      await tap(t, find.byKey(const Key('confirm-pt-cancel')));
      expect(writes, 1);
      expect(find.textContaining('Server reason'), findsWidgets);
      expect(find.byKey(const Key('pt-cancel')), findsNothing);
    },
  );
  testWidgets(
    'eligibility false is fresh snapshot; complete has no eligibility precondition',
    (t) async {
      var eligibleReads = 0, writes = 0, complete = false;
      final next = {
        ...f.booking(),
        'status': 'COMPLETED',
        'completedAt': '2030-01-02T04:30:00Z',
      };
      final api = ApiClient(
        expectedRole: 'PT',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.url.path.endsWith('/service-eligibility')) {
            eligibleReads++;
            return f.json({
              'eligible': false,
              'checkedAt': '2030-01-02T04:30:00Z',
              'reasonCodes': ['SESSION_ENDED'],
            });
          }
          if (r.method == 'POST') {
            writes++;
            expect(r.url.path.endsWith('/complete'), isTrue);
            complete = true;
            return f.json(next);
          }
          return f.json(
            r.url.path.endsWith('/bookings')
                ? [complete ? next : f.booking()]
                : [],
          );
        }),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      await tap(t, find.text('Buổi tập').last);
      await tap(t, find.byKey(const ValueKey('session-${f.bookingId}')));
      await tap(t, find.byKey(const Key('eligibility')));
      expect(find.text('Chưa đủ điều kiện'), findsOneWidget);
      expect(find.textContaining('SESSION_ENDED'), findsOneWidget);
      expect(find.textContaining('2030-01-02T04:30:00.000Z'), findsOneWidget);
      await tap(t, find.byKey(const Key('close-eligibility')));
      await tap(t, find.byKey(const Key('eligibility')));
      expect(eligibleReads, 2);
      await tap(t, find.byKey(const Key('close-eligibility')));
      await tap(t, find.byKey(const Key('complete')));
      await tap(t, find.byKey(const Key('confirm-complete')));
      expect(writes, 1);
      expect(find.text('Đã hoàn tất'), findsOneWidget);
    },
  );
  for (final failure in ['conflict', 'network'])
    test(
      'navigation state locks ambiguous $failure without replay and reconciles on explicit reload',
      () async {
        var writes = 0;
        final api = ApiClient(
          expectedRole: 'PT',
          baseUri: Uri.parse('http://localhost/api/v1'),
          client: MockClient((r) async {
            if (r.url.path.endsWith('/login')) return f.json(auth());
            if (r.method == 'POST') {
              writes++;
              if (failure == 'network') throw http.ClientException('offline');
              return f.json({
                'error': {
                  'code': 'ERR_SLOT_OVERLAP',
                  'message': 'Conflict',
                  'correlationId': 'original-state',
                },
              }, 409);
            }
            return f.json([]);
          }),
        );
        addTearDown(api.dispose);
        await api.login('test', 'test');
        final state = BookingState(BookingService(api));
        addTearDown(state.dispose);
        await state.refresh();
        await state.act(() => state.saveSlot(DateTime.utc(2030)));
        expect(writes, 1);
        expect(state.message, isNull);
        expect(
          state.error,
          contains(failure == 'network' ? 'NETWORK_ERROR' : 'ERR_SLOT_OVERLAP'),
        );
        if (failure == 'network') {
          await state.act(() => state.saveSlot(DateTime.utc(2030)));
          expect(writes, 1);
          await state.refresh(manual: true);
          expect(state.blocked, isFalse);
        }
      },
    );
  testWidgets(
    'logout removes pushed session detail even if eligibility response arrives late',
    (t) async {
      final pending = Completer<http.Response>();
      final api = ApiClient(
        expectedRole: 'PT',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return f.json(auth());
          if (r.url.path.endsWith('/service-eligibility'))
            return pending.future;
          return f.json(r.url.path.endsWith('/bookings') ? [f.booking()] : []);
        }),
      );
      addTearDown(api.dispose);
      await enter(t, api);
      await tap(t, find.text('Buổi tập').last);
      await tap(t, find.byKey(const ValueKey('session-${f.bookingId}')));
      await t.tap(find.byKey(const Key('eligibility')));
      await t.pump();
      api.logout();
      await t.pumpAndSettle();
      pending.complete(
        f.json({
          'eligible': true,
          'checkedAt': '2030-01-02T03:00:00Z',
          'reasonCodes': [],
        }),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('login')), findsOneWidget);
      expect(find.textContaining('Đủ điều kiện tại'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('logout removes open reason dialog and its private draft', (
    t,
  ) async {
    final api = ApiClient(
      expectedRole: 'PT',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return f.json(auth());
        return f.json(r.url.path.endsWith('/bookings') ? [f.booking()] : []);
      }),
    );
    addTearDown(api.dispose);
    await enter(t, api);
    await tap(t, find.text('Buổi tập').last);
    await tap(t, find.byKey(const ValueKey('session-${f.bookingId}')));
    await tap(t, find.byKey(const Key('pt-cancel')));
    await t.enterText(
      find.byKey(const Key('cancel-reason')),
      'Private old-account draft',
    );
    api.logout();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Private old-account draft'), findsNothing);
    expect(find.byKey(const Key('login')), findsOneWidget);
  });
}
