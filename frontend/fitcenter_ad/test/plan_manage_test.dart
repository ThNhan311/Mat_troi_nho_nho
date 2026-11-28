import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/screens/membership_page.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/membership_plan_service.dart';

const id = '20000000-0000-4000-8000-000000000001';

Map<String, dynamic> plan() => {
  'id': id,
  'name': 'Goi thang',
  'description': null,
  'durationDays': 30,
  'price': 100000,
};

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<List<http.Request>> open(
  WidgetTester t,
  Future<http.Response> Function(http.Request) onWrite,
) async {
  await t.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final writes = <http.Request>[];
  final api = ApiClient(
    expectedRole: 'ADMIN',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login')) {
        return json({'role': 'ADMIN', 'accessToken': 'a', 'refreshToken': 'r'});
      }
      if (r.method != 'GET') {
        writes.add(r);
        return onWrite(r);
      }
      return json([plan()]);
    }),
  );
  addTearDown(api.dispose);
  await api.login('admin@example.invalid', 'synthetic');
  await t.pumpWidget(
    MaterialApp(
      home: MembershipPage(
        service: MembershipPlanService(api),
        onLogout: () {},
      ),
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

void main() {
  test('money is grouped for reading', () {
    expect(moneyText(10000000), '100.000 VND');
    expect(moneyText(123456789), '1.234.567,89 VND');
    expect(moneyText(0), '0 VND');
  });

  test('days are shown in the largest exact unit', () {
    expect(durationText(37), '37 ngày');
    expect(durationText(90), '3 tháng (90 ngày)');
    expect(durationText(730), '2 năm (730 ngày)');
    expect(validateDuration('0', DurationUnit.year), isNotNull);
    expect(validateDuration('2147483647', DurationUnit.month), isNotNull);
    expect(validateDuration('2', DurationUnit.year), isNull);
  });

  testWidgets('a number of years is sent as days', (t) async {
    final writes = await open(
      t,
      (r) async => json({...plan(), ...jsonDecode(r.body)}),
    );
    expect(find.text('Thời hạn: 1 tháng (30 ngày)'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('edit-plan-$id')));
    // 30 days open as one month.
    expect(find.text('1'), findsOneWidget);
    await tap(t, find.byKey(const Key('plan-unit')));
    await tap(t, find.text('Năm').last);
    await t.enterText(find.byType(TextFormField).at(2), '2');
    await t.pump();
    expect(find.textContaining('= 730 ngày'), findsOneWidget);
    await tap(t, find.text('Lưu'));
    expect(jsonDecode(writes.single.body)['durationDays'], 730);
  });

  testWidgets('edit starts from the current values and sends them', (t) async {
    final writes = await open(
      t,
      (r) async => json({...plan(), ...jsonDecode(r.body)}),
    );
    expect(find.text('100.000 VND'), findsOneWidget);
    expect(find.textContaining('Mã gói:'), findsNothing);
    await tap(t, find.byKey(const ValueKey('edit-plan-$id')));
    expect(find.text('100000'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).at(1), '150000');
    await tap(t, find.text('Lưu'));
    expect(writes.single.method, 'PUT');
    expect(writes.single.url.path, '/api/v1/admin/membership-plans/$id');
    expect(jsonDecode(writes.single.body), {
      'name': 'Goi thang',
      'description': null,
      'durationDays': 30,
      'price': 150000,
    });
  });

  for (final result in ['DELETED', 'ARCHIVED']) {
    testWidgets('delete asks first and reports $result', (t) async {
      final writes = await open(t, (_) async => json({'result': result}));
      await tap(t, find.byKey(const ValueKey('delete-plan-$id')));
      await tap(t, find.text('Hủy'));
      expect(writes, isEmpty);
      await tap(t, find.byKey(const ValueKey('delete-plan-$id')));
      await tap(t, find.byKey(const Key('confirm-plan-delete')));
      expect(writes.single.method, 'DELETE');
      expect(
        find.text(
          result == 'DELETED'
              ? 'Đã xóa gói tập.'
              : 'Gói đã có người mua nên chỉ ngừng bán.',
        ),
        findsOneWidget,
      );
    });
  }
}
