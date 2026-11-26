import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/screens/account_page.dart';
import 'package:fitcenter_ad/services/admin_account_service.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/kiosk_desk_service.dart';

const profile = '20000000-0000-0000-0000-000000000001';

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<ApiClient> admin(MockClientHandler handler) async {
  final api = ApiClient(
    expectedRole: 'ADMIN',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login')) {
        return json({'role': 'ADMIN', 'accessToken': 'a', 'refreshToken': 'r'});
      }
      if (r.url.path.endsWith('/admin/members')) {
        return json([
          {
            'userId': '10000000-0000-0000-0000-000000000001',
            'profileId': profile,
            'email': 'an@example.invalid',
            'fullName': 'An',
            'role': 'MEMBER',
            'status': 'ACTIVE',
            'activationPending': false,
          },
        ]);
      }
      return handler(r);
    }),
  );
  await api.login('admin@example.invalid', 'synthetic');
  return api;
}

Future<void> show(WidgetTester t, Widget page) async {
  await t.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(home: page));
  await t.pumpAndSettle();
}

Map<String, dynamic> request(String status) => {
  'requestId': 'r-1',
  'memberName': 'An',
  'status': status,
};

Widget accounts(ApiClient api) => AccountsPage(
  service: AdminAccountService(api),
  onLogout: () {},
  kiosk: KioskDeskService(api),
);

void main() {
  testWidgets('face button sends the profile id and follows the result', (
    t,
  ) async {
    var status = 'WAITING';
    final bodies = <String>[];
    var cancels = 0;
    final api = await admin((r) async {
      if (r.method == 'POST') {
        bodies.add(r.body);
        return json(request('WAITING'));
      }
      if (r.method == 'DELETE') {
        cancels++;
        return http.Response('', 204);
      }
      return json({'enrollment': request(status), 'recent': []});
    });
    await show(t, accounts(api));
    await t.tap(find.byKey(const ValueKey('face-$profile')));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump();
    expect(jsonDecode(bodies.single), {'memberId': profile});
    expect(find.textContaining('Mời An'), findsOneWidget);
    status = 'SUCCESS';
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Đã lưu khuôn mặt của An.'), findsOneWidget);
    await t.tap(find.byKey(const Key('face-close')));
    await t.pumpAndSettle();
    expect(cancels, 0);
    api.dispose();
  });

  testWidgets('skipping while waiting cancels the request', (t) async {
    var cancels = 0;
    final api = await admin((r) async {
      if (r.method == 'POST') return json(request('WAITING'));
      if (r.method == 'DELETE') {
        cancels++;
        return http.Response('', 204);
      }
      return json({'enrollment': request('WAITING'), 'recent': []});
    });
    await show(t, accounts(api));
    await t.tap(find.byKey(const ValueKey('face-$profile')));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byKey(const Key('face-close')));
    await t.pumpAndSettle();
    expect(cancels, 1);
    expect(find.byKey(const Key('face-close')), findsNothing);
    api.dispose();
  });

  test('an expired session is renewed and the capture request sent once more', () async {
    var posts = 0;
    final api = await admin((r) async {
      if (r.url.path.endsWith('/refresh')) {
        return json({'role': 'ADMIN', 'accessToken': 'b', 'refreshToken': 's'});
      }
      posts++;
      return posts == 1
          ? http.Response('{}', 401)
          : json(request('WAITING'));
    });
    final sent = await KioskDeskService(api).requestEnrollment(profile);
    expect(sent.status, 'WAITING');
    expect(posts, 2);
    api.dispose();
  });

  testWidgets('without a camera screen there is no face button', (t) async {
    final api = await admin((r) async => json([]));
    await show(
      t,
      AccountsPage(service: AdminAccountService(api), onLogout: () {}),
    );
    expect(find.byKey(const ValueKey('face-$profile')), findsNothing);
    api.dispose();
  });
}
