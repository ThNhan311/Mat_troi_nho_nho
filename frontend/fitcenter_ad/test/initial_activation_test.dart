import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/services/initial_activation_service.dart';
import 'package:fitcenter_ad/screens/initial_activation_page.dart';
import 'package:fitcenter_ad/services/api_client.dart';

const member = '10000000-0000-4000-8000-000000000001',
    plan = '10000000-0000-4000-8000-000000000002',
    ms = '10000000-0000-4000-8000-000000000003',
    pay = '10000000-0000-4000-8000-000000000004';
Map<String, dynamic> dto(String key) => {
  'activationId': plan,
  'requestId': key,
  'memberId': member,
  'membership': {
    'id': ms,
    'planId': plan,
    'planName': 'Fixture plan',
    'startDate': '2030-02-01',
    'endDate': '2030-03-02',
    'status': 'ACTIVE',
  },
  'payment': {
    'id': pay,
    'provider': 'COUNTER',
    'providerRef': 'counter:$pay',
    'amount': 0,
    'status': 'SUCCESS',
    'processedAt': '2030-02-01T00:00:00Z',
  },
  'receipt': {
    'receiptRef': 'DEMO-01',
    'confirmedByUserId': plan,
    'confirmedAt': '2030-02-01T00:00:00Z',
  },
  'planSnapshot': {
    'name': 'Fixture plan',
    'durationDays': 30,
    'listedPrice': 0,
    'currency': 'VND',
  },
};
http.Response json(Object? b, [int status = 200]) => http.Response(
  jsonEncode(b),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient api(Future<http.Response> Function(http.Request) f) => ApiClient(
  expectedRole: 'ADMIN',
  baseUri: Uri.parse('http://localhost/api/v1'),
  client: MockClient((r) async {
    if (r.url.path.endsWith('/login'))
      return json({
        'role': 'ADMIN',
        'accessToken': 'test-access',
        'refreshToken': 'test-refresh',
      });
    if (r.url.path.endsWith('/membership-plans'))
      return json([
        {
          'id': plan,
          'name': 'Fixture plan',
          'description': null,
          'durationDays': 30,
          'price': 0,
        },
      ]);
    if (r.url.path.endsWith('/admin/members'))
      return json([
        {
          'userId': plan,
          'profileId': member,
          'email': 'fixture@example.invalid',
          'fullName': 'Fixture Member',
          'role': 'MEMBER',
          'status': 'DISABLED',
          'activationPending': true,
        },
      ]);
    return f(r);
  }),
);
Future<void> open(WidgetTester t, ApiClient a, {bool app = false}) async {
  await t.binding.setSurfaceSize(const Size(1024, 1600));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await a.login('fixture@example.invalid', 'test-only');
  await t.pumpWidget(
    app
        ? FitCenterAdminApp(api: a)
        : MaterialApp(
            home: InitialActivationPage(service: InitialActivationService(a)),
          ),
  );
  await t.pumpAndSettle();
  if (app) {
    await t.ensureVisible(find.text('Kích hoạt Gói hội viên'));
    await t.tap(find.text('Kích hoạt Gói hội viên'));
    await t.pumpAndSettle();
  }
}

Future<void> fill(WidgetTester t) async {
  await t.tap(find.byKey(const Key('initial-member')));
  await t.pumpAndSettle();
  await t.tap(find.textContaining('Fixture Member').last);
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('initial-plan')));
  await t.pumpAndSettle();
  await t.tap(find.textContaining('Fixture plan').last);
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('initial-receipt')), 'DEMO-01');
  await t.tap(find.byType(Checkbox));
  await t.pumpAndSettle();
}

Future<void> submit(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('initial-submit')));
  await t.tap(find.byKey(const Key('initial-submit')));
  await t.pumpAndSettle();
  await t.tap(find.text('Xác nhận đã thu tiền'));
  await t.pump();
}

void main() {
  test('key UUID random and version4', () {
    final a = newActivationKey(), b = newActivationKey();
    expect(a, b != a ? isNot(b) : isNull);
    expect(
      a,
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
  });
  test('DTO calendar and immutable snapshot fields, including price zero', () {
    final a = InitialActivation.parse(dto(member));
    expect(a.cents, 0);
    expect(a.membershipId, ms);
    expect(a.endDate, '2030-03-02');
    expect(a.confirmedAt.isUtc, isTrue);
    expect(calendarDate('+10000-02-29'), '+10000-02-29');
    expect(() => calendarDate('2030-02-30'), throwsFormatException);
  });
  for (final field in ['membership', 'payment', 'receipt', 'planSnapshot'])
    test('malformed $field never success', () {
      final data = dto(member)..remove(field);
      expect(
        () => InitialActivation.parse(data, write: true),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'uncertain', true),
        ),
      );
    });
  for (final status in [200, 201])
    test(
      'accept only expected create/replay status $status with exact target/key',
      () async {
        final a = api((r) async {
          expect(r.headers['Idempotency-Key'], member);
          expect(
            r.url.path,
            '/api/v1/admin/members/$member/activate-membership',
          );
          expect(r.method, 'POST');
          return json(dto(member), status);
        });
        addTearDown(a.dispose);
        await a.login('fixture', 'test');
        final result = await InitialActivationService(a).create(
          member,
          member,
          {'planId': plan, 'amountCollected': 0, 'receiptRef': 'DEMO-01'},
        );
        expect(result.membershipId, ms);
      },
    );
  test('mismatched member/key/price response rejected', () async {
    final a = api((r) async => json({...dto(member), 'memberId': plan}, 201));
    addTearDown(a.dispose);
    await a.login('fixture', 'test');
    await expectLater(
      InitialActivationService(a)
          .create(member, member, {'planId': plan, 'amountCollected': 0}),
      throwsA(isA<ApiError>()),
    );
  });
  testWidgets(
    'original Home activation separate from account; confirmation then server-only success',
    (t) async {
      var writes = 0;
      final a = api((r) async {
        if (r.method == 'POST') {
          writes++;
          expect(jsonDecode(r.body), {
            'planId': plan,
            'amountCollected': 0,
            'receiptRef': 'DEMO-01',
            'note': null,
          });
          return json(dto(r.headers['Idempotency-Key']!), 201);
        }
        return json({});
      });
      addTearDown(a.dispose);
      await open(t, a, app: true);
      await fill(t);
      expect(find.textContaining('Số tiền: 0.00'), findsOneWidget);
      await t.tap(find.byKey(const Key('initial-submit')));
      await t.pumpAndSettle();
      expect(writes, 0);
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      await submit(t);
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(
        find.text('Đã ghi nhận kích hoạt Membership ACTIVE'),
        findsOneWidget,
      );
      expect(find.text(ms), findsOneWidget);
      expect(
        find.textContaining('Tài khoản đăng nhập không thay đổi'),
        findsOneWidget,
      );
    },
  );
  testWidgets('double-submit disabled until pending request resolves', (
    t,
  ) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    String? key;
    final a = api((r) async {
      writes++;
      key = r.headers['Idempotency-Key'];
      return pending.future;
    });
    addTearDown(a.dispose);
    await open(t, a);
    await fill(t);
    await submit(t);
    expect(writes, 1);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('initial-submit'))).onPressed,
      isNull,
    );
    pending.complete(json(dto(key!), 201));
    await t.pumpAndSettle();
    expect(writes, 1);
  });
  testWidgets(
    'network uncertainty requires GET before explicit same-key retry, no blind replay',
    (t) async {
      var writes = 0, reads = 0;
      String? first, retried;
      final a = api((r) async {
        if (r.method == 'GET') {
          reads++;
          return json({
            'error': {'code': 'ERR_NOT_FOUND', 'message': 'No record'},
          }, 404);
        }
        writes++;
        if (writes == 1) {
          first = r.headers['Idempotency-Key'];
          throw http.ClientException('offline');
        }
        retried = r.headers['Idempotency-Key'];
        return json(dto(first!), 200);
      });
      addTearDown(a.dispose);
      await open(t, a);
      await fill(t);
      await submit(t);
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(
        find.text('Đã ghi nhận kích hoạt Membership ACTIVE'),
        findsNothing,
      );
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const Key('initial-retry')))
            .onPressed,
        isNull,
      );
      await t.tap(find.byKey(const Key('initial-read')));
      await t.pumpAndSettle();
      expect(reads, 1);
      expect(writes, 1);
      final retry = t
          .widget<OutlinedButton>(find.byKey(const Key('initial-retry')))
          .onPressed!;
      retry();
      retry();
      await t.pumpAndSettle();
      expect(writes, 2);
      expect(retried, first);
      expect(find.text(ms), findsOneWidget);
    },
  );
  testWidgets('409 visible without fake success', (t) async {
    var writes = 0;
    final a = api((r) async {
      writes++;
      return json({
        'error': {
          'code': 'ERR_RECEIPT_ALREADY_USED',
          'message': 'Receipt used',
          'correlationId': 'm03-test',
        },
      }, 409);
    });
    addTearDown(a.dispose);
    await open(t, a);
    await fill(t);
    await submit(t);
    await t.pumpAndSettle();
    expect(writes, 1);
    expect(find.textContaining('ERR_RECEIPT_ALREADY_USED'), findsOneWidget);
    expect(find.textContaining('m03-test'), findsOneWidget);
    expect(find.text('Đã ghi nhận kích hoạt Membership ACTIVE'), findsNothing);
  });
  testWidgets('logout while confirmation modal open drops modal and route', (
    t,
  ) async {
    final a = api((r) async => json({}));
    addTearDown(a.dispose);
    await open(t, a, app: true);
    await fill(t);
    await t.tap(find.byKey(const Key('initial-submit')));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    a.logout();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('login')), findsOneWidget);
  });
  testWidgets('logout during write discards old private response', (t) async {
    final pending = Completer<http.Response>();
    String? key;
    final a = api((r) async {
      key = r.headers['Idempotency-Key'];
      return pending.future;
    });
    addTearDown(a.dispose);
    await open(t, a, app: true);
    await fill(t);
    await submit(t);
    a.logout();
    await t.pumpAndSettle();
    pending.complete(json(dto(key!), 201));
    await t.pumpAndSettle();
    expect(find.text(ms), findsNothing);
    expect(find.byKey(const Key('login')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'read committed original result after reload/navigation, no POST',
    (t) async {
      var writes = 0;
      final a = api((r) async {
        if (r.method == 'POST') writes++;
        return json(dto(member));
      });
      addTearDown(a.dispose);
      await open(t, a);
      await fill(t);
      await t.tap(find.byKey(const Key('initial-read')));
      await t.pumpAndSettle();
      expect(writes, 0);
      expect(find.text(ms), findsOneWidget);
    },
  );
}
