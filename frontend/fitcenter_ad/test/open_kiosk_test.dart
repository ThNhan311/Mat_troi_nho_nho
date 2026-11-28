import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/screens/open_kiosk_button.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/kiosk_desk_service.dart';

void main() {
  for (final status in [204, 503]) {
    testWidgets('open button sends one request and reports $status', (t) async {
      final sent = <String>[];
      final api = ApiClient(
        expectedRole: 'ADMIN',
        baseUri: Uri.parse('http://localhost/api/v1'),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'role': 'ADMIN',
                'accessToken': 'a',
                'refreshToken': 'r',
              }),
              200,
            );
          }
          sent.add('${r.method} ${r.url.path}');
          return http.Response(status == 204 ? '' : '{}', status);
        }),
      );
      addTearDown(api.dispose);
      await api.login('admin@example.invalid', 'synthetic');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OpenKioskButton(service: KioskDeskService(api))),
        ),
      );
      await t.tap(find.byKey(const Key('open-kiosk')));
      await t.pumpAndSettle();
      expect(sent, ['POST /api/v1/admin/kiosk/open']);
      expect(
        find.textContaining(
          status == 204 ? 'Đang mở màn hình' : 'chưa được cấu hình',
        ),
        findsOneWidget,
      );
    });
  }
}
