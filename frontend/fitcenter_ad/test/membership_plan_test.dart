import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/membership_plan_service.dart';
import 'package:fitcenter_ad/screens/membership_page.dart';

Map<String, dynamic> dto({
  String id = '10000000-0000-0000-0000-000000000001',
  num price = 0,
}) => {
  'id': id,
  'name': 'Synthetic plan',
  'description': null,
  'durationDays': 37,
  'price': price,
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient api(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 15),
}) => ApiClient(
  expectedRole: 'ADMIN',
  baseUri: Uri.parse('http://localhost/api/v1'),
  timeout: timeout,
  client: MockClient(
    (r) async => r.url.path.endsWith('/login')
        ? json({
            'role': 'ADMIN',
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
          })
        : handler(r),
  ),
);
Future<void> login(ApiClient a) =>
    a.login('synthetic@example.invalid', 'test-only');
Future<void> open(WidgetTester t, ApiClient a, {bool app = false}) async {
  await login(a);
  await t.pumpWidget(
    app
        ? FitCenterAdminApp(api: a)
        : MaterialApp(
            home: MembershipPage(
              service: MembershipPlanService(a),
              onLogout: a.logout,
            ),
          ),
  );
  if (app) {
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Gói tập'));
    await t.tap(find.text('Gói tập'));
  }
  await t.pumpAndSettle();
}

Future<void> dialog(WidgetTester t) async {
  await t.tap(find.text('Thêm gói'));
  await t.pumpAndSettle();
}

Future<void> fill(WidgetTester t, {String price = '0'}) async {
  final f = find.byType(TextFormField);
  await t.enterText(f.at(0), 'Synthetic plan');
  await t.enterText(f.at(1), price);
  await t.enterText(f.at(2), '37');
}

void main() {
  for (final value in ['', '-1', '0.001', '10000000000', '1e2', 'abc', 'NaN']) {
    test(
      'invalid exact price $value',
      () => expect(validatePlanPrice(value), isNotNull),
    );
  }
  for (final value in ['0', '0.01', '9999999999.99']) {
    test(
      'valid exact price $value',
      () => expect(validatePlanPrice(value), isNull),
    );
  }
  test('name character length and int32 days only', () {
    expect(validatePlanName(' '), isNotNull);
    expect(validatePlanName('🏋' * 100), isNull);
    expect(validatePlanName('a' * 101), isNotNull);
    for (final v in ['0', '-1', '1.0', '2147483648']) {
      expect(validateDurationDays(v), isNotNull);
    }
    expect(validateDurationDays('2147483647'), isNull);
  });
  test('DTO rejects invalid UUID days precision and wrong array mapping', () {
    for (final change in [
      {'id': 'fake'},
      {'durationDays': 0},
      {'durationDays': 1.5},
      {'price': 0.001},
      {'price': -1},
      {'description': 7},
    ]) {
      expect(
        () => MembershipPlan.parse({...dto(), ...change}),
        throwsA(isA<ApiError>()),
      );
    }
    expect(MembershipPlan.parse(dto(price: 9999999999.99)).cents, 999999999999);
  });
  test(
    'create sends whitelist JSON number and only accepts matching 201',
    () async {
      final a = api((r) async {
        expect(r.method, 'POST');
        expect(jsonDecode(r.body), {
          'name': 'Synthetic plan',
          'description': null,
          'durationDays': 37,
          'price': 0.0,
        });
        return json(dto(), 201);
      });
      addTearDown(a.dispose);
      await login(a);
      expect(
        (await MembershipPlanService(
          a,
        ).create(name: 'Synthetic plan', durationDays: 37, cents: 0)).id,
        dto()['id'],
      );
    },
  );
  for (final status in [200, 201]) {
    test('wrong create status/DTO $status is unknown', () async {
      final a = api((_) async => json(status == 201 ? {} : dto(), status));
      addTearDown(a.dispose);
      await login(a);
      await expectLater(
        MembershipPlanService(a)
            .create(name: 'Synthetic plan', durationDays: 37, cents: 0),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    });
  }
  test('mismatched create response never announces success', () async {
    final a = api((_) async => json(dto(price: 1), 201));
    addTearDown(a.dispose);
    await login(a);
    await expectLater(
      MembershipPlanService(a)
          .create(name: 'Synthetic plan', durationDays: 37, cents: 0),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
  });
  test('POST timeout is attempted once', () async {
    int writes = 0;
    final a = api((_) async {
      writes++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return json(dto(), 201);
    }, timeout: const Duration(milliseconds: 5));
    addTearDown(a.dispose);
    await login(a);
    await expectLater(
      MembershipPlanService(a)
          .create(name: 'Synthetic plan', durationDays: 37, cents: 0),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
    expect(writes, 1);
  });
  test('list requires array and uses GET, not Admin read clone', () async {
    var body = <String, dynamic>{};
    final a = api((r) async {
      expect(r.url.path, '/api/v1/membership-plans');
      return json(body);
    });
    addTearDown(a.dispose);
    await login(a);
    await expectLater(
      MembershipPlanService(a).list(),
      throwsA(isA<ApiError>()),
    );
  });
  testWidgets('loading, empty then server list and unsupported actions', (
    t,
  ) async {
    var gate = Completer<http.Response>();
    int writes = 0;
    final a = api((r) async {
      if (r.method != 'GET') writes++;
      return gate.future;
    });
    addTearDown(a.dispose);
    await login(a);
    await t.pumpWidget(
      MaterialApp(
        home: MembershipPage(
          service: MembershipPlanService(a),
          onLogout: a.logout,
        ),
      ),
    );
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(json([]));
    await t.pumpAndSettle();
    expect(find.text('Chưa có gói tập đang hoạt động.'), findsOneWidget);
    gate = Completer<http.Response>();
    gate.complete(json([dto()]));
    await t.tap(find.byTooltip('Tải lại danh sách'));
    await t.pumpAndSettle();
    expect(find.text('Thời hạn: 37 ngày'), findsOneWidget);
    // Actions without a backend are not offered at all.
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(find.byType(Switch), findsNothing);
    expect(writes, 0);
  });
  testWidgets('GET error/correlation no mock fallback', (t) async {
    final a = api(
      (_) async => json({
        'error': {
          'code': 'FAIL',
          'message': 'Cannot read',
          'correlationId': 'trace-m01',
        },
      }, 500),
    );
    addTearDown(a.dispose);
    await open(t, a);
    expect(find.textContaining('trace-m01'), findsOneWidget);
    expect(find.text('Synthetic plan'), findsNothing);
  });
  testWidgets(
    '201 updates real ID and reload; same name is allowed and zero is valid',
    (t) async {
      int writes = 0, reads = 0;
      final a = api((r) async {
        if (r.method == 'GET') {
          reads++;
          return json([dto()]);
        }
        writes++;
        return json(dto(id: '20000000-0000-0000-0000-000000000002'), 201);
      });
      addTearDown(a.dispose);
      await open(t, a);
      await dialog(t);
      await fill(t);
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(reads, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Mã gói vừa tạo: 20000000'), findsOneWidget);
    },
  );
  testWidgets('form validation blocks zero days and excessive price scale', (
    t,
  ) async {
    int writes = 0;
    final a = api((r) async {
      if (r.method == 'POST') writes++;
      return json([]);
    });
    addTearDown(a.dispose);
    await open(t, a);
    await dialog(t);
    await fill(t, price: '0.001');
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(writes, 0);
    expect(find.textContaining('tối đa 2 số'), findsOneWidget);
  });
  testWidgets('pending create prevents double submit', (t) async {
    final gate = Completer<http.Response>();
    int writes = 0;
    final a = api((r) async {
      if (r.method == 'GET') return json([]);
      writes++;
      return gate.future;
    });
    addTearDown(a.dispose);
    await open(t, a);
    await dialog(t);
    await fill(t);
    await t.tap(find.text('Lưu'));
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
    expect(writes, 1);
    gate.complete(json(dto(), 201));
    await t.pumpAndSettle();
    expect(writes, 1);
  });
  testWidgets(
    'network unknown locks save, GET reconciliation never replays or identifies by name',
    (t) async {
      int writes = 0, reads = 0;
      final a = api((r) async {
        if (r.method == 'GET') {
          reads++;
          return json([dto()]);
        }
        writes++;
        throw http.ClientException('offline');
      });
      addTearDown(a.dispose);
      await open(t, a);
      await dialog(t);
      await fill(t);
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(find.textContaining('Tên gói có thể trùng'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
      await t.ensureVisible(find.text('Tải lại danh sách để đối chiếu'));
      await t.tap(find.text('Tải lại danh sách để đối chiếu'));
      await t.pumpAndSettle();
      expect(reads, 2);
      expect(writes, 1);
      expect(find.textContaining('Đã thêm gói tập từ máy chủ.'), findsNothing);
    },
  );
  testWidgets('409 shows code and no success', (t) async {
    final a = api(
      (r) async => r.method == 'GET'
          ? json([])
          : json({
              'error': {
                'code': 'ERR_CONFLICT',
                'message': 'Conflict',
                'correlationId': 'trace',
              },
            }, 409),
    );
    addTearDown(a.dispose);
    await open(t, a);
    await dialog(t);
    await fill(t);
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(find.textContaining('ERR_CONFLICT'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  for (final pendingWrite in [false, true]) {
    testWidgets(
      'logout removes modal and stale ${pendingWrite ? 'POST' : 'GET'} response',
      (t) async {
        final gate = Completer<http.Response>();
        final a = api(
          (r) async =>
              pendingWrite && r.method == 'GET' ? json([]) : gate.future,
        );
        addTearDown(a.dispose);
        if (pendingWrite) {
          await open(t, a, app: true);
          await dialog(t);
          await fill(t);
          await t.tap(find.text('Lưu'));
          await t.pump();
        } else {
          await login(a);
          await t.pumpWidget(FitCenterAdminApp(api: a));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('Gói tập'));
          await t.tap(find.text('Gói tập'));
          await t.pump();
        }
        a.logout();
        await t.pumpAndSettle();
        gate.complete(pendingWrite ? json(dto(), 201) : json([dto()]));
        await t.pumpAndSettle();
        expect(find.byType(MembershipPage), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const Key('login')), findsOneWidget);
        expect(
          find.textContaining('Đã thêm gói tập từ máy chủ.'),
          findsNothing,
        );
      },
    );
  }
}
