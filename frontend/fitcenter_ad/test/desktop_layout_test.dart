import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/services/api_client.dart';

Map<String, dynamic> account(int n, String role, {bool pending = false}) => {
  'userId': '10000000-0000-0000-0000-00000000000$n',
  'profileId': '20000000-0000-0000-0000-00000000000$n',
  'email': 'user$n@example.invalid',
  'fullName': 'Tài khoản $n',
  'role': role,
  'status': pending ? 'DISABLED' : 'ACTIVE',
  'activationPending': pending,
};

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<List<String>> start(WidgetTester t, Size size) async {
  await t.binding.setSurfaceSize(size);
  addTearDown(() => t.binding.setSurfaceSize(null));
  final writes = <String>[];
  final api = ApiClient(
    expectedRole: 'ADMIN',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/login')) {
        return json({'role': 'ADMIN', 'accessToken': 'a', 'refreshToken': 'r'});
      }
      if (r.method != 'GET') writes.add(r.method);
      if (path.endsWith('/admin/members')) {
        return json([
          account(1, 'MEMBER'),
          account(2, 'MEMBER', pending: true),
          account(3, 'MEMBER'),
        ]);
      }
      if (path.endsWith('/admin/personal-trainers')) {
        return json([account(4, 'PT')]);
      }
      return json([]);
    }),
  );
  addTearDown(api.dispose);
  await api.login('admin@example.invalid', 'synthetic');
  await t.pumpWidget(FitCenterAdminApp(api: api));
  await t.pumpAndSettle();
  return writes;
}

void main() {
  testWidgets('wide window opens on the schedule, without an overview', (
    t,
  ) async {
    final writes = await start(t, const Size(1440, 900));
    expect(find.byKey(const ValueKey('admin-menu-0')), findsOneWidget);
    expect(
      find.text('Không có buổi tập nào trong khoảng này.'),
      findsOneWidget,
    );
    expect(find.text('Tổng quan'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(writes, isEmpty);
  });

  testWidgets('accounts are a table, without duplicate logout buttons', (
    t,
  ) async {
    await start(t, const Size(1440, 900));
    await t.tap(find.byKey(const ValueKey('admin-menu-1')));
    await t.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('user1@example.invalid'), findsOneWidget);
    expect(find.byTooltip('Đăng xuất'), findsNothing);
    expect(find.text('Đăng xuất'), findsOneWidget); // sidebar
    expect(t.takeException(), isNull);
  });

  testWidgets('plans use a header button instead of a floating one', (t) async {
    await start(t, const Size(1440, 900));
    await t.tap(find.byKey(const ValueKey('admin-menu-2')));
    await t.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Thêm gói'), findsOneWidget);
  });

  testWidgets('every menu entry opens without layout errors', (t) async {
    await start(t, const Size(1100, 720));
    for (var i = 0; i < 6; i++) {
      await t.tap(find.byKey(ValueKey('admin-menu-$i')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'menu entry $i');
    }
  });

  testWidgets('narrow window keeps the menu list', (t) async {
    await start(t, const Size(800, 1200));
    expect(find.byKey(const ValueKey('admin-menu-0')), findsNothing);
    expect(find.text('QUẢN LÝ HỆ THỐNG'), findsOneWidget);
  });
}
