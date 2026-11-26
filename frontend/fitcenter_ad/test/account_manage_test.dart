import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/screens/account_page.dart';
import 'package:fitcenter_ad/services/admin_account_service.dart';
import 'package:fitcenter_ad/services/api_client.dart';

const user = '10000000-0000-4000-8000-000000000001',
    profile = '10000000-0000-4000-8000-000000000002',
    plan = '10000000-0000-4000-8000-000000000003';

Map<String, dynamic> account(String name) => {
  'userId': user,
  'profileId': profile,
  'email': 'an@example.invalid',
  'fullName': name,
  'role': 'MEMBER',
  'status': 'DISABLED',
  'activationPending': true,
};

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// [writes] receives every request that is not a read.
Future<List<http.Request>> open(
  WidgetTester t, {
  Map<String, dynamic>? detail,
  Future<http.Response> Function(http.Request)? onWrite,
  Future<http.Response> Function(http.Request)? onActivationRead,
  List<Map<String, dynamic>> visits = const [],
}) async {
  await t.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final writes = <http.Request>[];
  final api = ApiClient(
    expectedRole: 'ADMIN',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/login')) {
        return json({'role': 'ADMIN', 'accessToken': 'a', 'refreshToken': 'r'});
      }
      if (r.method != 'GET') {
        writes.add(r);
        return onWrite!(r);
      }
      if (path.endsWith('/membership-activation')) {
        return onActivationRead!(r);
      }
      if (path.endsWith('/admin/attendance')) {
        return json(visits);
      }
      if (path.endsWith('/account-details')) {
        return json([
          {'profileId': profile, 'face': null, ...?detail},
        ]);
      }
      if (path.endsWith('/membership-plans')) {
        return json([
          {
            'id': plan,
            'name': 'Goi thu',
            'description': null,
            'durationDays': 30,
            'price': 0,
          },
        ]);
      }
      return json([account('An')]);
    }),
  );
  addTearDown(api.dispose);
  await api.login('admin@example.invalid', 'synthetic');
  await t.pumpWidget(
    MaterialApp(
      home: AccountsPage(service: AdminAccountService(api), onLogout: () {}),
    ),
  );
  await t.pumpAndSettle();
  return writes;
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> fillNewMember(WidgetTester t) async {
  await tap(t, find.text('Thêm tài khoản'));
  await t.enterText(find.byKey(const Key('add-name')), 'An');
  await t.enterText(find.byKey(const Key('add-email')), 'an@example.invalid');
  await t.enterText(find.byKey(const Key('add-phone')), '0901234567');
  await tap(t, find.byKey(const Key('add-plan')));
  await tap(t, find.textContaining('Goi thu').last);
  await t.enterText(find.byKey(const Key('add-receipt')), 'PT-01');
}

void main() {
  testWidgets(
    'table shows phone and package; no package button when one exists',
    (t) async {
      await open(
        t,
        detail: {
          'phone': '0901234567',
          'planName': 'Goi thang',
          'planState': 'ACTIVE',
          'validUntil': '2030-03-02',
        },
      );
      expect(find.text('0901234567'), findsOneWidget);
      expect(find.text('Goi thang\nCòn hạn đến 02/03/2030'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-$profile')), findsNothing);
    },
  );

  testWidgets('check-in history belongs to the account, not to the name', (
    t,
  ) async {
    await open(
      t,
      visits: [
        {
          'at': '2030-01-02T03:04:00Z',
          'profileId': profile,
          'name': 'An',
          'role': 'MEMBER',
        },
        {
          'at': '2030-01-01T01:00:00Z',
          'profileId': user,
          'name': 'An',
          'role': 'PT',
        },
      ],
    );
    expect(find.text('02/01/2030 10:04'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('history-$profile')));
    expect(find.text('Lịch sử check-in: An'), findsOneWidget);
    expect(find.text('1 lượt trong 90 ngày qua.'), findsOneWidget);
    expect(find.text('01/01/2030'), findsNothing);
    await tap(t, find.byKey(const Key('history-close')));
  });

  testWidgets('member without a package gets the package button', (t) async {
    await open(t, detail: {'planState': null});
    expect(find.text('Chưa có gói'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-$profile')), findsOneWidget);
  });

  testWidgets('edit sends name, email and phone', (t) async {
    final writes = await open(t, onWrite: (_) async => http.Response('', 204));
    await tap(t, find.byKey(const ValueKey('edit-$profile')));
    await t.enterText(find.byKey(const Key('edit-name')), 'An Moi');
    await t.enterText(find.byKey(const Key('edit-phone')), '0912 345 678');
    await tap(t, find.byKey(const Key('edit-save')));
    expect(writes.single.method, 'PATCH');
    expect(writes.single.url.path, '/api/v1/admin/accounts/$user');
    expect(jsonDecode(writes.single.body), {
      'fullName': 'An Moi',
      'email': 'an@example.invalid',
      'phone': '0912345678',
    });
  });

  testWidgets('delete needs confirmation and shows a refusal', (t) async {
    final writes = await open(
      t,
      onWrite: (_) async => json({
        'error': {'code': 'ERR_CONFLICT', 'message': 'Account has history'},
      }, 409),
    );
    await tap(t, find.byKey(const ValueKey('delete-$profile')));
    await tap(t, find.text('Hủy'));
    expect(writes, isEmpty);
    await tap(t, find.byKey(const ValueKey('delete-$profile')));
    await tap(t, find.byKey(const Key('confirm-action')));
    expect(writes.single.method, 'DELETE');
    expect(find.textContaining('Account has history'), findsOneWidget);
    expect(find.text('Đã xóa tài khoản.'), findsNothing);
  });

  testWidgets('a trainer has no phone or package fields', (t) async {
    await open(t);
    await tap(t, find.text('Thêm tài khoản'));
    await tap(t, find.text('Hội viên').last);
    await tap(t, find.text('Huấn luyện viên').last);
    expect(find.byKey(const Key('add-phone')), findsNothing);
    expect(find.byKey(const Key('add-plan')), findsNothing);
  });

  testWidgets('unclear payment is checked first and resent with the same key', (
    t,
  ) async {
    final writes = await open(
      t,
      onWrite: (r) async {
        if (r.url.path.endsWith('/activate-membership')) {
          throw http.ClientException('offline');
        }
        return json(account('An'), 201);
      },
      onActivationRead: (_) async => json({
        'error': {'code': 'ERR_NOT_FOUND', 'message': 'None'},
      }, 404),
    );
    await fillNewMember(t);
    await tap(t, find.text('Thêm và thu tiền'));
    expect(writes, hasLength(2));
    expect(jsonDecode(writes[0].body)['phone'], '0901234567');
    expect(jsonDecode(writes[1].body)['receiptRef'], 'PT-01');
    expect(find.textContaining('Chưa rõ gói "Goi thu"'), findsOneWidget);
    expect(find.byKey(const Key('plan-submit')), findsNothing);
    FilledButton retry() =>
        t.widget<FilledButton>(find.byKey(const Key('plan-retry')));
    expect(retry().onPressed, isNull);
    await tap(t, find.byKey(const Key('plan-check')));
    expect(retry().onPressed, isNotNull);
    await tap(t, find.byKey(const Key('plan-retry')));
    expect(writes, hasLength(3));
    expect(
      writes[2].headers['Idempotency-Key'],
      writes[1].headers['Idempotency-Key'],
    );
    expect(writes[2].body, writes[1].body);
  });
}
