import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/renewal_models.dart';
import 'package:fitcenter_ad/services/payment_simulator_service.dart';
import 'package:fitcenter_ad/screens/payment_simulator_page.dart';

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
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      timeout: const Duration(milliseconds: 100),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login'))
          return response({
            'role': 'ADMIN',
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
        home: PaymentSimulatorPage(service: PaymentSimulatorService(client)),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> submit(WidgetTester t, String state) async {
    await t.ensureVisible(find.byKey(ValueKey('$paymentId-$state')));
    await t.tap(find.byKey(ValueKey('$paymentId-$state')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await t.pumpAndSettle();
  }

  test(
    'simulator command uses immutable decimal snapshot and provider reference',
    () {
      final client = api((r) async => response([])),
          service = PaymentSimulatorService(client);
      expect(service.command(RenewalPayment.parse(quote()), 'SUCCESS', keyId), {
        'eventId': keyId,
        'providerRef': 'sim:$paymentId',
        'amount': 0,
        'currency': 'VND',
        'status': 'SUCCESS',
      });
    },
  );
  testWidgets('empty and loading are server-driven', (t) async {
    final wait = Completer<http.Response>(), client = api((r) => wait.future);
    await client.login('unit@example.invalid', 'unit-only');
    await t.pumpWidget(
      MaterialApp(
        home: PaymentSimulatorPage(service: PaymentSimulatorService(client)),
      ),
    );
    await t.pump();
    expect(find.byKey(const Key('simulator-loading')), findsOneWidget);
    wait.complete(response([]));
    await t.pumpAndSettle();
    expect(find.text('Chưa có giao dịch gia hạn.'), findsOneWidget);
  });
  for (final state in ['SUCCESS', 'FAILED', 'CANCELLED']) {
    testWidgets('confirmed $state uses one POST and reloads actual status', (
      t,
    ) async {
      int writes = 0;
      Map<String, dynamic> row = quote();
      final client = api((r) async {
        if (r.method == 'POST') {
          writes++;
          final command = jsonDecode(r.body);
          row = quote(
            status: state,
            fulfillment: state == 'SUCCESS' ? 'APPLIED' : 'NOT_APPLIED',
          );
          return response({
            ...row,
            'eventId': command['eventId'],
            'eventOutcome': state == 'SUCCESS' ? 'APPLIED' : state,
          });
        }
        return response([row]);
      });
      await screen(t, client);
      await submit(t, state);
      expect(writes, 1);
      expect(find.text(RenewalPayment.parse(row).statusLabel), findsOneWidget);
      if (state != 'SUCCESS')
        expect(find.text('Đã cấp kỳ sử dụng'), findsNothing);
    });
  }
  testWidgets('409 keeps true pending status and surfaces code', (t) async {
    final client = api(
      (r) async => r.method == 'POST'
          ? response({
              'error': {
                'code': 'ERR_PAYMENT_RESULT_CONFLICT',
                'message': 'Conflict',
              },
            }, 409)
          : response([quote()]),
    );
    await screen(t, client);
    await submit(t, 'SUCCESS');
    expect(find.textContaining('ERR_PAYMENT_RESULT_CONFLICT'), findsOneWidget);
    expect(find.text('Chờ xác nhận thanh toán'), findsOneWidget);
    expect(find.text('Đã cấp kỳ sử dụng'), findsNothing);
  });
  testWidgets(
    'uncertain result does not replay, GET enables same-event retry',
    (t) async {
      final events = <String>[];
      Map<String, dynamic> row = quote();
      final client = api((r) async {
        if (r.method == 'POST') {
          final command = jsonDecode(r.body);
          events.add(command['eventId']);
          if (events.length == 1)
            throw http.ClientException('synthetic offline');
          row = quote(status: 'SUCCESS', fulfillment: 'APPLIED');
          return response({
            ...row,
            'eventId': command['eventId'],
            'eventOutcome': 'APPLIED',
          });
        }
        if (r.url.path.endsWith('/events')) return response([]);
        return response([row]);
      });
      await screen(t, client);
      await submit(t, 'SUCCESS');
      expect(events.length, 1);
      expect(
        t
            .widget<TextButton>(find.byKey(const Key('simulator-retry')))
            .onPressed,
        isNull,
      );
      await t.tap(find.byTooltip('Tải lại giao dịch'));
    await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('simulator-retry')));
      await t.tap(find.byKey(const Key('simulator-retry')));
      await t.pumpAndSettle();
      expect(events.length, 2);
      expect(events[0], events[1]);
    },
  );
  testWidgets('logout removes rows and discards in-flight response', (t) async {
    final wait = Completer<http.Response>(), client = api((r) => wait.future);
    await client.login('unit@example.invalid', 'unit-only');
    await t.pumpWidget(
      MaterialApp(
        home: PaymentSimulatorPage(service: PaymentSimulatorService(client)),
      ),
    );
    await t.pump();
    client.logout();
    await t.pump();
    wait.complete(response([quote()]));
    await t.pumpAndSettle();
    expect(find.textContaining(paymentId), findsNothing);
    expect(find.text('Xác nhận đã nhận tiền'), findsNothing);
  });
}
