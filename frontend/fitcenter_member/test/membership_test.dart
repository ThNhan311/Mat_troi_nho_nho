import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/main.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/membership_service.dart';
import 'package:fitcenter/screens/membership_page.dart';

import 'pull.dart';

const id = '11111111-1111-4111-8111-111111111111';
const plan = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> row({
  String status = 'ACTIVE',
  String? start = '2026-11-23',
  String? end = '2026-11-23',
  String uuid = id,
}) => {
  'id': uuid,
  'planId': plan,
  'planName': 'Gói tổng hợp',
  'startDate': start,
  'endDate': end,
  'status': status,
};
http.Response json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient client(Future<http.Response> Function(http.Request) handle) =>
    ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({
            'role': 'MEMBER',
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
          });
        }
        return handle(r);
      }),
    );
Future<void> screen(WidgetTester t, ApiClient api) async {
  await api.login('fixture@example.invalid', 'test-only');
  await t.pumpWidget(
    MaterialApp(home: MembershipPage(service: MembershipService(api))),
  );
}

void main() {
  test('expanded ISO DATE from long duration keeps calendar without a new business cap', () {
    final m = Membership.fromJson(row(end: '+10000-02-29'));
    expect(Membership.displayDate(m.endDate), '29/02/+10000');
    expect(
      Membership.fromJson(row(end: '+5874897-12-31')).endDate,
      '+5874897-12-31',
    );
    expect(
      () => Membership.fromJson(row(end: '+10001-02-29')),
      throwsA(isA<ApiError>()),
    );
  });
  for (final status in Membership.labels.keys) {
    test(
      'DTO preserves $status and calendar date, without client status inference',
      () {
        final value = Membership.fromJson(row(status: status));
        expect(value.id, id);
        expect(value.planId, plan);
        expect(value.status, status);
        expect(value.startDate, '2026-11-23');
        expect(value.endDate, '2026-11-23');
        expect(Membership.displayDate(value.endDate), '23/11/2026');
      },
    );
  }
  test('pending dates nullable; impossible or offset dates rejected', () {
    expect(
      Membership.fromJson(
        row(status: 'PENDING_ACTIVATION', start: null, end: null),
      ).endDate,
      isNull,
    );
    for (final date in ['2026-02-30', '2026-11-23T00:00:00Z', '23/11/2026']) {
      expect(
        () => Membership.fromJson(row(start: date)),
        throwsA(isA<ApiError>()),
      );
    }
    expect(Membership.displayDate(null), 'Chưa xác định');
  });
  test('invalid UUID, unknown status, missing name rejected', () {
    for (final value in [
      row(uuid: 'bad'),
      row(status: 'UNKNOWN'),
      {...row()}..remove('planName'),
    ]) {
      expect(() => Membership.fromJson(value), throwsA(isA<ApiError>()));
    }
  });
  test('GET array mapping; no owner ID query and no writes', () async {
    final api = client((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/v1/memberships/me');
      expect(r.url.hasQuery, isFalse);
      return json([row(status: 'CANCELLED'), row(uuid: plan)]);
    });
    addTearDown(api.dispose);
    await api.login('fixture', 'test');
    final rows = await MembershipService(api).mine();
    expect(rows.map((r) => r.id), [id, plan]);
  });
  test('object envelope not silently accepted instead of array', () async {
    final api = client(
      (r) async => json({
        'data': [row()],
      }),
    );
    addTearDown(api.dispose);
    await api.login('fixture', 'test');
    await expectLater(MembershipService(api).mine(), throwsA(isA<ApiError>()));
  });
  testWidgets(
    'loading, empty and reload; no sample price/history or current selection',
    (t) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final api = client((r) async {
        calls++;
        return calls == 1 ? pending.future : json([row()]);
      });
      addTearDown(api.dispose);
      await screen(t, api);
      await t.pump();
      expect(find.byKey(const Key('membership-loading')), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      pending.complete(json([]));
      await t.pumpAndSettle();
      expect(find.text('Bạn chưa có gói hội viên.'), findsOneWidget);
      await pullToReload(t);
      expect(find.byKey(const ValueKey('membership-$id')), findsOneWidget);
      expect(find.text('23/11/2026'), findsNWidgets(2));
      expect(find.text('Gia hạn Membership'), findsOneWidget);
      expect(find.text('Gói cao cấp'), findsNothing);
      expect(find.text('Buổi đã tập'), findsNothing);
      expect(find.text('Lịch sử gia hạn'), findsNothing);
    },
  );
  testWidgets('all records shown, cancelled first is not chosen as current', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1024, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final api = client(
      (r) async => json([
        row(status: 'CANCELLED'),
        row(uuid: plan, status: 'PENDING_ACTIVATION', start: null, end: null),
      ]),
    );
    addTearDown(api.dispose);
    await screen(t, api);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('membership-$id')), findsOneWidget);
    expect(find.byKey(const ValueKey('membership-$plan')), findsOneWidget);
    expect(find.text('Đã hủy'), findsOneWidget);
    expect(find.text('Chờ kích hoạt'), findsOneWidget);
    expect(find.text('Chưa xác định'), findsNWidgets(2));
  });
  for (final offline in [false, true]) {
    testWidgets('error visible and manual recovery offline=$offline', (
      t,
    ) async {
      var fail = true;
      final api = client((r) async {
        if (!fail) return json([]);
        if (offline) throw http.ClientException('offline');
        return json({
          'error': {
            'code': 'TEST_DENIED',
            'message': 'Không được phép',
            'correlationId': 'm04-test',
          },
        }, 403);
      });
      addTearDown(api.dispose);
      await screen(t, api);
      await t.pumpAndSettle();
      expect(
        find.textContaining(offline ? 'NETWORK_ERROR' : 'TEST_DENIED'),
        findsOneWidget,
      );
      if (!offline) expect(find.textContaining('m04-test'), findsOneWidget);
      expect(find.byKey(const Key('membership-empty')), findsNothing);
      fail = false;
      await pullToReload(t);
      expect(find.byKey(const Key('membership-empty')), findsOneWidget);
    });
  }
  testWidgets('expired refresh returns login, with bounded requests', (
    t,
  ) async {
    var gets = 0, refreshes = 0;
    final api = client((r) async {
      if (r.url.path.endsWith('/refresh')) {
        refreshes++;
      } else if (r.url.path.endsWith('/memberships/me'))
        gets++;
      if (r.url.path.endsWith('/trainers') ||
          r.url.path.endsWith('/bookings/me')) {
        return json([]);
      }
      return json({
        'error': {'code': 'UNAUTHORIZED', 'message': 'Hết phiên'},
      }, 401);
    });
    addTearDown(api.dispose);
    await api.login('fixture', 'test');
    await t.pumpWidget(FitCenterApp(api: api));
    await t.pumpAndSettle();
    await t.tap(find.text('Gói hội viên').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('login')), findsOneWidget);
    // One non-renewing read by the home overview, one by the membership page.
    expect(gets, 2);
    expect(refreshes, 1);
  });
  testWidgets(
    'logout/account switch discards delayed private response and old route',
    (t) async {
      final pending = Completer<http.Response>();
      var first = true;
      final api = client((r) async {
        if (r.url.path.endsWith('/memberships/me')) {
          return first ? pending.future : json([]);
        }
        return json([]);
      });
      addTearDown(api.dispose);
      await api.login('a', 'test');
      await t.pumpWidget(FitCenterApp(api: api));
      await t.pumpAndSettle();
      await t.tap(find.text('Gói hội viên').last);
      await t.pump();
      api.logout();
      await t.pumpAndSettle();
      first = false;
      await api.login('b', 'test');
      await t.pumpAndSettle();
      pending.complete(json([row()]));
      await t.pumpAndSettle();
      await t.tap(find.text('Gói hội viên').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('membership-empty')), findsOneWidget);
      expect(find.text(id), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
