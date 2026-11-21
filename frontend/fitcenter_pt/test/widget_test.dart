import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_pt/main.dart';
import 'package:fitcenter_pt/services/api_client.dart';

const ptId = '10000000-0000-0000-0000-000000000001';
const slotId = '20000000-0000-0000-0000-000000000002';
const bookingId = '30000000-0000-0000-0000-000000000003';
const memberId = '40000000-0000-0000-0000-000000000004';
Map<String, dynamic> slot([String status = 'AVAILABLE']) => {
  'id': slotId,
  'ptId': ptId,
  'startAt': '2030-01-02T03:00:00Z',
  'endAt': '2030-01-02T04:30:00Z',
  'status': status,
};
Map<String, dynamic> booking() => {
  'id': bookingId,
  'memberId': memberId,
  'ptId': ptId,
  'slotId': slotId,
  'startAt': '2030-01-02T03:00:00Z',
  'endAt': '2030-01-02T04:30:00Z',
  'status': 'CONFIRMED',
};
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
Future<void> login(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(FitCenterApp(api: api));
  await tester.enterText(
    find.byKey(const Key('email')),
    'fixture@example.invalid',
  );
  await tester.enterText(find.byKey(const Key('password')), 'test-only');
  await tester.tap(find.byKey(const Key('login')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'PT screen with mocked HTTP uses own endpoints, waits for 201 and refreshes',
    (tester) async {
      final result = Completer<http.Response>();
      var writes = 0, created = false;
      final api = ApiClient(
        expectedRole: 'PT',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'role': 'PT',
              'accessToken': 'access-test',
              'refreshToken': 'refresh-test',
            });
          }
          expect(r.url.path, startsWith('/api/v1/pt/'));
          expect(r.headers['Authorization'], 'Bearer access-test');
          if (r.method == 'POST') {
            writes++;
            expect(r.url.path, '/api/v1/pt/availability');
            expect(jsonDecode(r.body), {
              'startAt': '2030-01-02T03:00:00.000Z',
              'endAt': '2030-01-02T04:30:00.000Z',
            });
            final response = await result.future;
            created = true;
            return response;
          }
          expect(r.url.queryParameters.keys, containsAll(['from', 'to']));
          if (r.url.path.endsWith('/slots')) {
            return json(created ? [slot()] : []);
          }
          return json([booking()]);
        }),
      );
      addTearDown(api.dispose);
      await login(tester, api);
      await tester.enterText(
        find.byKey(const Key('slot-start')),
        '2030-01-02 10:00',
      );
      await tester.ensureVisible(find.byKey(const Key('create-slot')));
      await tester.tap(find.byKey(const Key('create-slot')));
      await tester.pump();
      expect(writes, 1);
      expect(find.byKey(const Key('success')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('create-slot')))
            .onPressed,
        isNull,
      );
      result.complete(json(slot(), 201));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('success')), findsOneWidget);
      expect(writes, 1);
      await tester.scrollUntilVisible(
        find.textContaining('Member: 40000000'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Member: 40000000'), findsOneWidget);
      expect(find.textContaining('Nguyễn'), findsNothing);
    },
  );
  testWidgets(
    'PT network failure never creates a fake slot or retries automatically',
    (tester) async {
      var writes = 0;
      final api = ApiClient(
        expectedRole: 'PT',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'role': 'PT',
              'accessToken': 'access-test',
              'refreshToken': 'refresh-test',
            });
          }
          if (r.method == 'POST') {
            writes++;
            throw http.ClientException('offline');
          }
          return json([]);
        }),
      );
      addTearDown(api.dispose);
      await login(tester, api);
      await tester.enterText(
        find.byKey(const Key('slot-start')),
        '2030-01-02 10:00',
      );
      await tester.tap(find.byKey(const Key('create-slot')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('success')), findsNothing);
      expect(writes, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('create-slot')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('NETWORK_ERROR'), findsOneWidget);
    },
  );
  testWidgets('invalid Vietnam date and past time send no POST', (
    tester,
  ) async {
    var writes = 0;
    final api = ApiClient(
      expectedRole: 'PT',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({
            'role': 'PT',
            'accessToken': 'access-test',
            'refreshToken': 'refresh-test',
          });
        }
        if (r.method == 'POST') writes++;
        return json([]);
      }),
    );
    addTearDown(api.dispose);
    await login(tester, api);
    for (final value in ['2030-02-31 10:00', '2000-01-01 10:00']) {
      await tester.enterText(find.byKey(const Key('slot-start')), value);
      await tester.tap(find.byKey(const Key('create-slot')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('api-error')), findsOneWidget);
    }
    expect(writes, 0);
  });
  testWidgets('PT read error has no demo sessions fallback', (tester) async {
    final api = ApiClient(
      expectedRole: 'PT',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({
            'role': 'PT',
            'accessToken': 'access-test',
            'refreshToken': 'refresh-test',
          });
        }
        throw http.ClientException('offline');
      }),
    );
    addTearDown(api.dispose);
    await login(tester, api);
    expect(find.byKey(const Key('api-error')), findsOneWidget);
    expect(find.textContaining('BK001'), findsNothing);
  });
}
