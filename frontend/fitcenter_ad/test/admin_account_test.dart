import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/admin_account_service.dart';
import 'package:fitcenter_ad/screens/account_page.dart';

Map<String, dynamic> dto() => {
  'userId': '10000000-0000-0000-0000-000000000001',
  'profileId': '20000000-0000-0000-0000-000000000002',
  'email': 'new@example.invalid',
  'fullName': 'Synthetic PT',
  'role': 'PT',
  'status': 'DISABLED',
  'activationPending': true,
};
http.Response json(Object b, [int s = 200]) => http.Response(
  jsonEncode(b),
  s,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient client(Future<http.Response> Function(http.Request) f) => ApiClient(
  expectedRole: 'ADMIN',
  baseUri: Uri.parse('http://localhost/api/v1'),
  client: MockClient(
    (r) async => r.url.path.endsWith('/login')
        ? json({'role': 'ADMIN', 'accessToken': 'test', 'refreshToken': 'test'})
        : f(r),
  ),
);
Future<void> open(WidgetTester t, ApiClient a, {bool app = false}) async {
  await a.login('test@example.invalid', 'synthetic');
  await t.pumpWidget(
    app
        ? FitCenterAdminApp(api: a)
        : MaterialApp(
            home: AccountsPage(
              service: AdminAccountService(a),
              onLogout: a.logout,
            ),
          ),
  );
  await t.pumpAndSettle();
  if (app) {
    await t.ensureVisible(find.text('Hội viên & PT'));
    await t.tap(find.text('Hội viên & PT'));
    await t.pumpAndSettle();
  }
}

Future<void> add(WidgetTester t) async {
  await t.tap(find.text('Thêm tài khoản'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextFormField).at(0), 'Synthetic PT');
  await t.enterText(find.byType(TextFormField).at(1), 'new@example.invalid');
  await t.enterText(find.byKey(const Key('add-phone')), '0901 234 567');
}

void main() {
  test('DTO preserves distinct identities and pending state', () {
    final a = AdminAccount.parse(dto());
    expect(a.userId, isNot(a.profileId));
    expect(a.statusLabel, 'Chưa kích hoạt');
    expect(
      () => AdminAccount.parse({...dto(), 'profileId': dto()['userId']}),
      throwsA(isA<ApiError>()),
    );
    expect(
      () => AdminAccount.parse({...dto(), 'status': 'ACTIVE'}),
      throwsA(isA<ApiError>()),
    );
  });
  test(
    'create only dedicated role path and email/fullName; no JWT/password',
    () async {
      final a = client((r) async {
        expect(r.url.path, '/api/v1/admin/personal-trainers');
        expect(jsonDecode(r.body), {
          'email': 'new@example.invalid',
          'fullName': 'Synthetic PT',
        });
        return json(dto(), 201);
      });
      addTearDown(a.dispose);
      await a.login('test@example.invalid', 'synthetic');
      expect(
        (await AdminAccountService(a).create(
          'PT',
          'new@example.invalid',
          'Synthetic PT',
        )).activationPending,
        true,
      );
    },
  );
  for (final status in [200, 201]) {
    test('unexpected create status/body $status is unknown', () async {
      final a = client((_) async => json(status == 201 ? {} : dto(), status));
      addTearDown(a.dispose);
      await a.login('test@example.invalid', 'synthetic');
      await expectLater(
        AdminAccountService(a)
            .create('PT', 'new@example.invalid', 'Synthetic PT'),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    });
  }
  testWidgets('list uses real DTO; showing actions never writes', (t) async {
    int writes = 0;
    final a = client((r) async {
      if (r.method != 'GET') writes++;
      return json([
        {...dto(), 'role': 'MEMBER'},
      ]);
    });
    addTearDown(a.dispose);
    await open(t, a);
    expect(find.text('Chưa kích hoạt'), findsOneWidget);
    expect(find.text('Synthetic PT'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(writes, 0);
  });
  testWidgets('empty/error never show sample accounts', (t) async {
    final a = client((_) async => json([]));
    addTearDown(a.dispose);
    await open(t, a);
    expect(find.text('Không tìm thấy tài khoản phù hợp.'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsNothing);
  });
  testWidgets('201 matching DTO only success and GET reload', (t) async {
    int posts = 0, gets = 0;
    final a = client((r) async {
      if (r.method == 'GET') {
        if (r.url.path.endsWith('/admin/members')) gets++;
        return json([]);
      }
      posts++;
      expect(jsonDecode(r.body)['phone'], '0901234567');
      return json({...dto(), 'role': 'MEMBER'}, 201);
    });
    addTearDown(a.dispose);
    await open(t, a);
    await add(t);
    await t.tap(find.text('Thêm'));
    await t.pumpAndSettle();
    expect(posts, 1);
    expect(gets, 2);
    expect(
      find.textContaining('Đã tạo tài khoản chưa kích hoạt.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets(
    'double submit and logout while modal POST pending removes stale response',
    (t) async {
      final gate = Completer<http.Response>();
      int writes = 0;
      final a = client((r) async {
        if (r.method == 'GET') return json([]);
        writes++;
        return gate.future;
      });
      addTearDown(a.dispose);
      await open(t, a, app: true);
      await add(t);
      await t.tap(find.text('Thêm'));
      await t.pump();
      expect(writes, 1);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Thêm'))
            .onPressed,
        null,
      );
      a.logout();
      await t.pumpAndSettle();
      gate.complete(json({...dto(), 'role': 'MEMBER'}, 201));
      await t.pumpAndSettle();
      expect(find.byType(AccountsPage), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('login')), findsOneWidget);
    },
  );
  testWidgets('network failure requires GET, no replay/no success', (t) async {
    int posts = 0;
    final a = client((r) async {
      if (r.method == 'GET') return json([]);
      posts++;
      throw http.ClientException('offline');
    });
    addTearDown(a.dispose);
    await open(t, a);
    await add(t);
    await t.tap(find.text('Thêm'));
    await t.pumpAndSettle();
    expect(posts, 1);
    expect(find.textContaining('Chưa rõ kết quả.'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Thêm'))
          .onPressed,
      null,
    );
    await t.ensureVisible(find.text('Tải lại danh sách để đối chiếu'));
    await t.tap(find.text('Tải lại danh sách để đối chiếu'));
    await t.pumpAndSettle();
    expect(posts, 1);
  });
  testWidgets('validation and409 never fake success', (t) async {
    int posts = 0;
    final a = client((r) async {
      if (r.method == 'GET') return json([]);
      posts++;
      return json({
        'error': {
          'code': 'ERR_CONFLICT',
          'message': 'Conflict',
          'correlationId': 'test-trace',
        },
      }, 409);
    });
    addTearDown(a.dispose);
    await open(t, a);
    await add(t);
    await t.enterText(find.byType(TextFormField).at(1), 'bad');
    await t.tap(find.text('Thêm'));
    await t.pumpAndSettle();
    expect(posts, 0);
    await t.enterText(find.byType(TextFormField).at(1), 'new@example.invalid');
    await t.tap(find.text('Thêm'));
    await t.pumpAndSettle();
    expect(find.textContaining('test-trace'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
