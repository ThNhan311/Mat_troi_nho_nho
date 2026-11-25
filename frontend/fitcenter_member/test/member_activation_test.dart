// Synthetic protocol vectors only, never actual OTP/grant/password values.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/member_activation_service.dart';
import 'package:fitcenter/screens/member_activation_page.dart';

http.Response json(Object b, [int s = 200]) => http.Response(
  jsonEncode(b),
  s,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiClient session() => ApiClient(
  expectedRole: 'MEMBER',
  baseUri: Uri.parse('http://localhost/api/v1'),
);
Future<void> page(WidgetTester t, MemberActivationService s) async {
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MemberActivationPage(service: s),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

Future<void> email(WidgetTester t) async {
  await t.enterText(
    find.byKey(const Key('activation-email')),
    'member@example.invalid',
  );
  await t.tap(find.text('Nhận OTP'));
  await t.pumpAndSettle();
}

void main() {
  test('public POST never sends Bearer or replays', () async {
    final a = session();
    addTearDown(a.dispose);
    int writes = 0;
    final s = MemberActivationService(
      a,
      client: MockClient((r) async {
        writes++;
        expect(r.headers['Authorization'], null);
        expect(
          r.headers['Cache-Control'],
          null,
        ); // No extra CORS request header.
        expect(jsonDecode(r.body), {'email': 'member@example.invalid'});
        return json({'expiresInSeconds': 300}, 202);
      }),
    );
    addTearDown(s.dispose);
    await s.request('member@example.invalid');
    expect(writes, 1);
    expect(a.authenticated, false);
  });
  test('timeout outcome unknown one attempt', () async {
    final a = session();
    addTearDown(a.dispose);
    int writes = 0;
    final s = MemberActivationService(
      a,
      timeout: const Duration(milliseconds: 5),
      client: MockClient((r) async {
        writes++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return json({'expiresInSeconds': 300}, 202);
      }),
    );
    addTearDown(s.dispose);
    await expectLater(
      s.request('member@example.invalid'),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
    expect(writes, 1);
  });
  test('wrong successful status/malformed verification is unknown', () async {
    final a = session();
    addTearDown(a.dispose);
    final s = MemberActivationService(
      a,
      client: MockClient(
        (r) async =>
            json({'verificationToken': 'invalid', 'expiresInSeconds': 300}),
      ),
    );
    addTearDown(s.dispose);
    await expectLater(
      s.verify('member@example.invalid', '000000'),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
  });
  testWidgets('schema503 shown; no OTP/password form or fake success', (
    t,
  ) async {
    final a = session();
    addTearDown(a.dispose);
    final s = MemberActivationService(
      a,
      client: MockClient(
        (r) async => json({
          'error': {'code': 'ERR_ACTIVATION_NOT_READY', 'message': 'not ready'},
        }, 503),
      ),
    );
    await page(t, s);
    await email(t);
    expect(
      find.textContaining('Kích hoạt Member chưa sẵn sàng.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activation-password')), findsNothing);
    expect(find.byKey(const Key('activation-otp')), findsNothing);
  });
  testWidgets(
    'password appears only after successful verify; no automatic login',
    (t) async {
      final a = session();
      addTearDown(a.dispose);
      final requests = <String>[];
      final s = MemberActivationService(
        a,
        client: MockClient((r) async {
          requests.add(r.url.path);
          if (r.url.path.endsWith('request-otp'))
            return json({'expiresInSeconds': 300}, 202);
          if (r.url.path.endsWith('verify-otp'))
            return json({
              'verificationToken': 'a' * 43,
              'expiresInSeconds': 300,
            });
          return json({'status': 'ACTIVE'});
        }),
      );
      await page(t, s);
      await email(t);
      expect(find.byKey(const Key('activation-password')), findsNothing);
      await t.enterText(find.byKey(const Key('activation-otp')), '000000');
      await t.tap(find.text('Xác thực OTP'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('activation-password')), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('activation-password')),
        'test-only-password',
      );
      await t.enterText(
        find.byKey(const Key('activation-confirm')),
        'test-only-password',
      );
      await t.tap(find.text('Hoàn tất kích hoạt'));
      await t.pumpAndSettle();
      expect(find.textContaining('Đã kích hoạt tài khoản.'), findsOneWidget);
      expect(requests.length, 3);
      expect(a.authenticated, false);
    },
  );
  testWidgets('invalid OTP and rate errors do not unlock password', (t) async {
    final a = session();
    addTearDown(a.dispose);
    final s = MemberActivationService(
      a,
      client: MockClient(
        (r) async => r.url.path.endsWith('request-otp')
            ? json({'expiresInSeconds': 300}, 202)
            : json({
                'error': {'code': 'ERR_OTP_ATTEMPT_LIMIT', 'message': 'limit'},
              }, 429),
      ),
    );
    await page(t, s);
    await email(t);
    await t.enterText(find.byKey(const Key('activation-otp')), '000000');
    await t.tap(find.text('Xác thực OTP'));
    await t.pumpAndSettle();
    expect(find.textContaining('ERR_OTP_ATTEMPT_LIMIT'), findsOneWidget);
    expect(find.byKey(const Key('activation-password')), findsNothing);
  });
  testWidgets(
    'session change closes activation route and discards pending response',
    (t) async {
      final a = session();
      addTearDown(a.dispose);
      final gate = Completer<http.Response>();
      final s = MemberActivationService(
        a,
        client: MockClient((r) => gate.future),
      );
      await page(t, s);
      await t.enterText(
        find.byKey(const Key('activation-email')),
        'member@example.invalid',
      );
      await t.tap(find.text('Nhận OTP'));
      await t.pump();
      a.logout();
      await t.pumpAndSettle();
      gate.complete(json({'expiresInSeconds': 300}, 202));
      await t.pumpAndSettle();
      expect(find.byType(MemberActivationPage), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    },
  );
}
