import 'dart:convert';

import 'package:fitcenter/main.dart' as app;
import 'package:fitcenter/screens/forgot_password_page.dart';
import 'package:fitcenter/services/api_client.dart';
import 'package:fitcenter/services/password_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'overview_test.dart' show login;
import 'widget_test.dart' as f;

ApiClient client(MockClient mock) => ApiClient(
  expectedRole: 'MEMBER',
  baseUri: Uri.parse('http://localhost/api/v1'),
  client: mock,
);

Future<void> press(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the login screen opens forgot password', (t) async {
    final api = client(MockClient((r) async => f.json([])));
    addTearDown(api.dispose);
    await t.pumpWidget(app.FitCenterApp(api: api));
    await t.enterText(find.byKey(const Key('email')), 'a@example.invalid');
    await press(t, find.byKey(const Key('forgot-password')));
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    // The address already typed is carried over.
    expect(find.text('a@example.invalid'), findsOneWidget);
  });

  testWidgets('forgot password: email, code, new password', (t) async {
    final paths = <String>[];
    var lastBody = <String, dynamic>{};
    var wrong = true;
    final api = client(MockClient((r) async => f.json([])));
    addTearDown(api.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ForgotPasswordPage(
          service: PasswordService(
            api,
            client: MockClient((r) async {
              paths.add(r.url.path.split('/').last);
              lastBody = jsonDecode(r.body) as Map<String, dynamic>;
              if (paths.last == 'request-otp') {
                return f.json({'expiresInSeconds': 300}, 202);
              }
              if (paths.last == 'verify-otp') {
                if (wrong) {
                  wrong = false;
                  return f.json({
                    'error': {'code': 'ERR_OTP_INVALID', 'message': 'Sai ma'},
                  }, 400);
                }
                return f.json({'verificationToken': 'grant-1'});
              }
              return f.json({'status': 'RESET'});
            }),
          ),
        ),
      ),
    );
    final submit = find.byKey(const Key('reset-submit'));
    await t.enterText(find.byKey(const Key('reset-email')), 'a@example.invalid');
    await press(t, submit);
    await t.enterText(find.byKey(const Key('reset-otp')), '111111');
    await press(t, submit);
    expect(find.text('Sai ma'), findsOneWidget);
    expect(find.byKey(const Key('reset-password')), findsNothing);
    await press(t, submit);
    await t.enterText(
      find.byKey(const Key('reset-password')),
      'brand-new-password',
    );
    await t.enterText(find.byKey(const Key('reset-confirm')), 'different-one');
    await press(t, submit);
    expect(find.text('Mật khẩu chưa khớp.'), findsOneWidget);
    expect(paths.where((p) => p == 'password'), isEmpty);
    await t.enterText(
      find.byKey(const Key('reset-confirm')),
      'brand-new-password',
    );
    await press(t, submit);
    expect(paths, ['request-otp', 'verify-otp', 'verify-otp', 'password']);
    expect(lastBody, {
      'verificationToken': 'grant-1',
      'password': 'brand-new-password',
    });
    expect(find.textContaining('Đã đổi mật khẩu'), findsOneWidget);
  });

  testWidgets('change password from the profile tab keeps the session', (
    t,
  ) async {
    final bodies = <Map<String, dynamic>>[];
    final api = client(
      MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/login')) return f.json(login);
        if (path.endsWith('/profile/password')) {
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          return bodies.length == 1
              ? f.json({
                  'error': {
                    'code': 'ERR_PASSWORD_CURRENT',
                    'message': 'Sai mat khau cu',
                  },
                }, 400)
              : f.json({'status': 'CHANGED'});
        }
        return f.json([]);
      }),
    );
    addTearDown(api.dispose);
    await api.login('fixture', 'test');
    await t.pumpWidget(app.FitCenterApp(api: api));
    await t.pumpAndSettle();
    await t.tap(find.text('Cá nhân').last);
    await t.pumpAndSettle();
    await press(t, find.text('Đổi mật khẩu'));
    await t.enterText(find.byKey(const Key('change-current')), 'old-password');
    await t.enterText(find.byKey(const Key('change-new')), 'brand-new-password');
    await t.enterText(
      find.byKey(const Key('change-confirm')),
      'brand-new-password',
    );
    await press(t, find.byKey(const Key('change-submit')));
    expect(find.text('Sai mat khau cu'), findsOneWidget);
    expect(api.authenticated, isTrue);
    await press(t, find.byKey(const Key('change-submit')));
    expect(find.textContaining('Đã đổi mật khẩu'), findsOneWidget);
    expect(bodies.last, {
      'currentPassword': 'old-password',
      'newPassword': 'brand-new-password',
    });
    expect(api.authenticated, isTrue);
  });
}
