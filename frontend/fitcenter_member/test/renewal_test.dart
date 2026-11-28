import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/renewal_models.dart';
import 'package:fitcenter/services/renewal_service.dart';
import 'package:fitcenter/screens/renewal_page.dart';

import 'pull.dart';
import 'package:fitcenter/screens/transfer_dialog.dart';

const paymentId = '10000000-0000-4000-8000-000000000001',
    membershipId = '10000000-0000-4000-8000-000000000002',
    memberId = '10000000-0000-4000-8000-000000000003',
    planId = '10000000-0000-4000-8000-000000000004',
    keyId = '10000000-0000-4000-8000-000000000005',
    periodId = '10000000-0000-4000-8000-000000000006';
Map<String, dynamic> quote({
  String key = keyId,
  String status = 'PENDING',
  String fulfillment = 'NOT_APPLIED',
}) => {
  'id': paymentId,
  'requestId': key,
  'membershipId': membershipId,
  'memberId': memberId,
  'planId': planId,
  'planName': 'Unit renewal plan',
  'provider': 'SIMULATOR',
  'providerRef': 'sim:$paymentId',
  'currency': 'VND',
  'amount': '0.00',
  'durationDays': 2,
  'status': status,
  'fulfillmentStatus': fulfillment,
  'reconciliationReason': fulfillment == 'RECONCILIATION_REQUIRED'
      ? 'MEMBERSHIP_STATE_CHANGED'
      : null,
  'periodId': fulfillment == 'APPLIED' ? periodId : null,
  'periodStart': fulfillment == 'APPLIED' ? '2028-03-01' : null,
  'periodEnd': fulfillment == 'APPLIED' ? '2028-03-02' : null,
  'createdAt': '2028-02-29T00:00:00Z',
  'processedAt': null,
};
http.Response response(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      expectedRole: 'MEMBER',
      baseUri: Uri.parse('http://localhost/api/v1'),
      timeout: const Duration(milliseconds: 100),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login'))
          return response({
            'role': 'MEMBER',
            'accessToken': 'unit-access',
            'refreshToken': 'unit-refresh',
          });
        return handler(request);
      }),
    );
void main() {
  test('new idempotency keys are UUIDv4 and independent', () {
    expect(newPaymentKey(), matches(RegExp(r'^[a-f0-9-]{14}4[a-f0-9-]+$')));
    expect(newPaymentKey(), isNot(newPaymentKey()));
  });
  test(
    'zero-price quote maps exact cents and never implies paid entitlement',
    () {
      final p = RenewalPayment.parse(quote());
      expect(p.cents, 0);
      expect(p.status, 'PENDING');
      expect(p.fulfillment, 'NOT_APPLIED');
    },
  );
  test('SUCCESS reconciliation is distinct from entitlement', () {
    final p = RenewalPayment.parse(
      quote(status: 'SUCCESS', fulfillment: 'RECONCILIATION_REQUIRED'),
    );
    expect(p.periodId, isNull);
    expect(p.fulfillmentLabel, contains('Cần đối soát'));
  });
  for (final entry in <String, dynamic>{
    'amount': 0,
    'durationDays': 0,
    'status': 'REFUNDED',
    'provider': 'GATEWAY',
    'currency': 'USD',
    'providerRef': 'bad',
    'requestId': 'bad',
    'createdAt': '2028-01-01',
  }.entries) {
    test('rejects malformed ${entry.key}', () {
      final row = quote();
      row[entry.key] = entry.value;
      expect(
        () => RenewalPayment.parse(row, write: true),
        throwsA(
          isA<ApiError>().having(
            (e) => e.outcomeUnknown,
            'unknown write outcome',
            true,
          ),
        ),
      );
    });
  }
  test('rejects half-applied metadata', () {
    final row = quote();
    row['periodStart'] = '2028-03-01';
    expect(() => RenewalPayment.parse(row), throwsA(isA<ApiError>()));
  });
  test(
    'paid periods preserve server phase and explicit legacy uncertainty',
    () {
      final p = PaidPeriod.parse({
        'id': periodId,
        'planId': planId,
        'source': 'LEGACY_AGGREGATE',
        'startDate': '2028-02-29',
        'endDate': '+10000-02-29',
        'phase': 'HISTORY',
        'planName': null,
        'amount': null,
        'durationDays': null,
        'currency': null,
      });
      expect(p.phase, 'HISTORY');
      expect(p.cents, isNull);
      expect(p.end, '+10000-02-29');
    },
  );

  Future<void> screen(WidgetTester t, ApiClient client) async {
    await client.login('unit@example.invalid', 'unit-only');
    await t.pumpWidget(
      MaterialApp(
        home: RenewalPage(
          service: RenewalService(client),
          membershipId: membershipId,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> select(WidgetTester t) async {
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Unit renewal plan').last);
    await t.pumpAndSettle();
  }

  Future<void> submit(WidgetTester t) async {
    await t.ensureVisible(find.byKey(const Key('renewal-create')));
    await t.tap(find.byKey(const Key('renewal-create')));
    await t.pumpAndSettle();
    await t.tap(find.text('Xác nhận'));
    await t.pumpAndSettle();
  }

  http.Response reads(http.Request r, List<Map<String, dynamic>> payments) {
    if (r.url.path.endsWith('/membership-plans'))
      return response([
        {
          'id': planId,
          'name': 'Unit renewal plan',
          'durationDays': 2,
          'price': 0,
        },
      ]);
    if (r.url.path.endsWith('/periods'))
      return response({
        'membershipId': membershipId,
        'checkedAt': '2028-02-29T00:00:00Z',
        'periods': [],
      });
    return response(payments);
  }

  test(
    'create sends owner-free plan UUID and retained key, accepts 200 replay',
    () async {
      late http.Request sent;
      final client = api((r) async {
        sent = r;
        return response(quote(key: r.headers['idempotency-key']!), 200);
      });
      await client.login('unit@example.invalid', 'unit-only');
      final p = await RenewalService(client)
          .create(membershipId, planId, keyId);
      expect(p.id, paymentId);
      expect(sent.headers['idempotency-key'], keyId);
      expect(jsonDecode(sent.body), {'planId': planId});
    },
  );
  test('timeout does not automatically replay a write', () async {
    int writes = 0;
    final client = api((r) async {
      writes++;
      throw http.ClientException('synthetic offline');
    });
    await client.login('unit@example.invalid', 'unit-only');
    await expectLater(
      RenewalService(client).create(membershipId, planId, keyId),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
    expect(writes, 1);
  });
  testWidgets('loading empty and plan selection preserve original page theme', (
    t,
  ) async {
    final wait = Completer<http.Response>();
    final client = api(
      (r) => r.url.path.endsWith('/membership-plans')
          ? wait.future
          : Future.value(reads(r, [])),
    );
    await client.login('unit@example.invalid', 'unit-only');
    await t.pumpWidget(
      MaterialApp(
        home: RenewalPage(
          service: RenewalService(client),
          membershipId: membershipId,
        ),
      ),
    );
    await t.pump();
    expect(find.byKey(const Key('renewal-loading')), findsOneWidget);
    wait.complete(
      response([
        {
          'id': planId,
          'name': 'Unit renewal plan',
          'durationDays': 2,
          'price': 0,
        },
      ]),
    );
    await t.pumpAndSettle();
    expect(find.text('Chưa có giao dịch gia hạn.'), findsOneWidget);
    expect(find.text('Chưa có kỳ sử dụng được xác minh.'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('renewal-create'))).onPressed,
      isNull,
    );
  });
  testWidgets('only server201 produces pending row, not SUCCESS', (t) async {
    int writes = 0;
    final rows = <Map<String, dynamic>>[];
    final client = api((r) async {
      if (r.method == 'POST') {
        writes++;
        rows.add({
          ...quote(key: r.headers['idempotency-key']!),
          'amount': '100000.00',
        });
        return response(rows.single, 201);
      }
      return reads(r, rows);
    });
    await screen(t, client);
    await select(t);
    await submit(t);
    expect(writes, 1);
    // The payment screen opens by itself; close it to see the list.
    expect(find.byType(TransferDialog), findsOneWidget);
    await t.tap(find.text('Đóng'));
    await t.pumpAndSettle();
    expect(find.text('Chờ xác nhận thanh toán'), findsOneWidget);
    expect(find.text('Đã cấp kỳ sử dụng'), findsNothing);
  });
  testWidgets('409 shows code and does not create a local payment', (t) async {
    final client = api(
      (r) async => r.method == 'POST'
          ? response({
              'error': {
                'code': 'ERR_MEMBERSHIP_NOT_RENEWABLE',
                'message': 'Blocked',
                'correlationId': 'unit-correlation',
              },
            }, 409)
          : reads(r, []),
    );
    await screen(t, client);
    await select(t);
    await submit(t);
    expect(find.textContaining('ERR_MEMBERSHIP_NOT_RENEWABLE'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-$paymentId')), findsNothing);
  });
  testWidgets(
    'uncertain write needs GET then retries with exactly the same key',
    (t) async {
      final keys = <String>[];
      final rows = <Map<String, dynamic>>[];
      final client = api((r) async {
        if (r.method == 'POST') {
          keys.add(r.headers['idempotency-key']!);
          if (keys.length == 1) throw http.ClientException('synthetic offline');
          rows.add(quote(key: keys.last));
          return response(rows.single, 201);
        }
        return reads(r, rows);
      });
      await screen(t, client);
      await select(t);
      await submit(t);
      expect(keys.length, 1);
      expect(
        t.widget<TextButton>(find.byKey(const Key('renewal-retry'))).onPressed,
        isNull,
      );
      await pullToReload(t);
      await t.ensureVisible(find.byKey(const Key('renewal-retry')));
      await t.tap(find.byKey(const Key('renewal-retry')));
      await t.pumpAndSettle();
      expect(keys.length, 2);
      expect(keys[0], keys[1]);
      // A free renewal has nothing to pay, so no payment screen opens.
      expect(find.byType(TransferDialog), findsNothing);
    },
  );
  testWidgets('old read response after logout is discarded', (t) async {
    final wait = Completer<http.Response>();
    final client = api((r) => wait.future);
    await client.login('unit@example.invalid', 'unit-only');
    await t.pumpWidget(
      MaterialApp(
        home: RenewalPage(
          service: RenewalService(client),
          membershipId: membershipId,
        ),
      ),
    );
    await t.pump();
    client.logout();
    await t.pump();
    wait.complete(
      response([
        {
          'id': planId,
          'name': 'Unit renewal plan',
          'durationDays': 2,
          'price': 0,
        },
      ]),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Unit renewal plan'), findsNothing);
    expect(find.byKey(const Key('renewal-create')), findsNothing);
  });
}
