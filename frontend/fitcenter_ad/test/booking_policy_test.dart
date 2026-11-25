import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/services/api_client.dart';
import 'package:fitcenter_ad/services/booking_policy_service.dart';
import 'package:fitcenter_ad/screens/booking_policy_page.dart';

Map<String, dynamic> dto({
  int days = 14,
  int notice = 2,
  int cancel = 4,
  int future = 5,
}) => {
  'id': '10000000-0000-0000-0000-000000000001',
  'maxAdvanceDays': days,
  'minNoticeHours': notice,
  'cancelDeadlineHours': cancel,
  'maxFutureBookings': future,
  'effectiveFrom': '2030-01-02T03:00:00Z',
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response tokens([String role = 'ADMIN']) => json({
  'role': role,
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
});
ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient(
        (r) async => r.url.path.endsWith('/login') ? tokens() : handler(r),
      ),
    );
Future<void> login(ApiClient api) =>
    api.login('synthetic@example.invalid', 'test-only');
Future<void> page(WidgetTester t, ApiClient api) async {
  await login(api);
  await t.pumpWidget(
    MaterialApp(
      home: BookingPolicyPage(
        service: BookingPolicyService(api),
        onLogout: api.logout,
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> fill(
  WidgetTester t, [
  List<String> values = const ['14', '2', '4', '5'],
]) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < 4; i++) {
    await t.enterText(fields.at(i), values[i]);
  }
  await t.pump();
}

Future<void> save(WidgetTester t) async {
  final button = find.widgetWithText(
    FilledButton,
    'Kiểm tra và lưu chính sách',
  );
  await t.ensureVisible(button);
  await t.tap(button);
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1024, 2200);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  for (final entry in <String, bool>{
    '': false,
    'null': false,
    '1.5': false,
    '1e2': false,
    '2147483648': false,
    '-1': false,
    '2147483647': true,
    '0': true,
  }.entries) {
    test('int32 validation ${entry.key}', () {
      expect(validatePolicyInteger(entry.key, 0) == null, entry.value);
    });
  }
  test('minimum only; no extra field relationships', () {
    expect(validatePolicyInteger('0', 1), isNotNull);
    expect(validatePolicyInteger('1', 1), isNull);
    expect(
      BookingPolicy.parse(dto(days: 1, notice: 200, cancel: 300, future: 1))
          .minNoticeHours,
      200,
    );
  });
  test('DTO rejects invalid id, int and timezone', () {
    for (final change in [
      {'id': 'fake'},
      {'maxAdvanceDays': 0},
      {'minNoticeHours': 2.5},
      {'maxFutureBookings': 2147483648},
      {'effectiveFrom': '2030-01-02T03:00:00'},
    ]) {
      expect(
        () => BookingPolicy.parse({...dto(), ...change}),
        throwsA(isA<ApiError>()),
      );
    }
    expect(
      BookingPolicy.parse(dto()).effectiveFrom,
      DateTime.utc(2030, 1, 2, 3),
    );
  });
  test('only exact policy-not-found maps to empty', () async {
    var code = 'BOOKING_POLICY_NOT_FOUND';
    final api = client(
      (_) async => json({
        'error': {'code': code, 'message': 'missing'},
      }, 404),
    );
    addTearDown(api.dispose);
    await login(api);
    final service = BookingPolicyService(api);
    expect(await service.read(), null);
    code = 'OTHER';
    await expectLater(service.read(), throwsA(isA<ApiError>()));
  });
  test(
    'PUT contains only four integer fields, accepts zero and int32 max',
    () async {
      final body = dto(days: 2147483647, notice: 0, cancel: 0, future: 1);
      final api = client((r) async {
        expect(r.method, 'PUT');
        expect(
          jsonDecode(r.body),
          (Map.of(body)
            ..remove('id')
            ..remove('effectiveFrom')),
        );
        return json(body);
      });
      addTearDown(api.dispose);
      await login(api);
      expect(
        (await BookingPolicyService(api)
                .save(BookingPolicy.parse(body).configuration))
            .maxAdvanceDays,
        2147483647,
      );
    },
  );
  for (final status in [200, 201]) {
    test('invalid PUT DTO/status $status is ambiguous', () async {
      final api = client((_) async => json(status == 200 ? {} : dto(), status));
      addTearDown(api.dispose);
      await login(api);
      await expectLater(
        BookingPolicyService(api)
            .save(BookingPolicy.parse(dto()).configuration),
        throwsA(
          isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true),
        ),
      );
    });
  }
  test('PUT response values must match requested config', () async {
    final api = client((_) async => json(dto(cancel: 9)));
    addTearDown(api.dispose);
    await login(api);
    await expectLater(
      BookingPolicyService(api).save(BookingPolicy.parse(dto()).configuration),
      throwsA(isA<ApiError>().having((e) => e.outcomeUnknown, 'unknown', true)),
    );
  });
  testWidgets('GET404 empty form; no automatic PUT; first save server DTO', (
    t,
  ) async {
    var writes = 0;
    final api = client((r) async {
      if (r.method == 'GET')
        return json({
          'error': {'code': 'BOOKING_POLICY_NOT_FOUND', 'message': 'missing'},
        }, 404);
      writes++;
      return json(dto());
    });
    addTearDown(api.dispose);
    await page(t, api);
    expect(find.textContaining('Chưa cấu hình chính sách.'), findsOneWidget);
    expect(writes, 0);
    expect(
      t
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '',
    );
    await fill(t);
    await save(t);
    expect(writes, 1);
    expect(find.text('Đã lưu chính sách từ máy chủ.'), findsOneWidget);
    expect(
      find.text('02/01/2030 10:00 (giờ Việt Nam, UTC+07:00)'),
      findsWidgets,
    );
    expect(find.byType(DatePickerDialog), findsNothing);
  });
  testWidgets('GET fills server values; validation blocks write', (t) async {
    var writes = 0;
    final api = client((r) async {
      if (r.method == 'PUT') writes++;
      return json(dto(days: 9, cancel: 7));
    });
    addTearDown(api.dispose);
    await page(t, api);
    expect(
      t
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '9',
    );
    await fill(t, ['0', '0', '0', '1']);
    await save(t);
    expect(writes, 0);
    expect(find.text('Giá trị phải từ 1 trở lên.'), findsOneWidget);
  });
  testWidgets('GET failure disables save; no fabricated policy', (t) async {
    final api = client(
      (_) async => json({
        'error': {
          'code': 'FAIL',
          'message': 'read failed',
          'correlationId': 'trace-test',
        },
      }, 500),
    );
    addTearDown(api.dispose);
    await page(t, api);
    expect(find.textContaining('trace-test'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
  });
  testWidgets('PUT unknown network outcome blocks replay until GET', (t) async {
    var writes = 0;
    final api = client((r) async {
      if (r.method == 'PUT') {
        writes++;
        throw http.ClientException('offline');
      }
      return json(dto());
    });
    addTearDown(api.dispose);
    await page(t, api);
    await save(t);
    expect(writes, 1);
    expect(
      find.textContaining('Chưa xác định được kết quả lưu.'),
      findsOneWidget,
    );
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
    await t.ensureVisible(find.text('Tải lại chính sách'));
    await t.tap(find.text('Tải lại chính sách'));
    await t.pumpAndSettle();
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(writes, 1);
  });
  testWidgets('PUT error shows code without success', (t) async {
    final api = client(
      (r) async => r.method == 'GET'
          ? json(dto())
          : json({
              'error': {
                'code': 'ERR_POLICY',
                'message': 'cannot save',
                'correlationId': 'trace',
              },
            }, 409),
    );
    addTearDown(api.dispose);
    await page(t, api);
    await save(t);
    expect(find.textContaining('ERR_POLICY'), findsOneWidget);
    expect(find.text('Đã lưu chính sách từ máy chủ.'), findsNothing);
  });
  testWidgets('save locks form and prevents double submit', (t) async {
    final gate = Completer<http.Response>();
    var writes = 0;
    final api = client((r) async {
      if (r.method == 'GET') return json(dto());
      writes++;
      return gate.future;
    });
    addTearDown(api.dispose);
    await page(t, api);
    final button = find.byType(FilledButton);
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(t.widget<FilledButton>(button).onPressed, null);
    expect(writes, 1);
    gate.complete(json(dto()));
    await t.pumpAndSettle();
    expect(writes, 1);
  });
  testWidgets('logout removes pushed policy route and stale GET response', (
    t,
  ) async {
    final gate = Completer<http.Response>();
    final api = client((_) => gate.future);
    addTearDown(api.dispose);
    await login(api);
    await t.pumpWidget(FitCenterAdminApp(api: api));
    await t.pumpAndSettle();
    final menu = find.text('Chính sách đặt lịch');
    await t.ensureVisible(menu);
    await t.tap(menu);
    await t.pump();
    api.logout();
    await t.pumpAndSettle();
    expect(find.byType(BookingPolicyPage), findsNothing);
    gate.complete(json(dto()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('login')), findsOneWidget);
    expect(find.text('Đã lưu chính sách từ máy chủ.'), findsNothing);
  });
  testWidgets('logout during PUT discards response and no success', (t) async {
    final gate = Completer<http.Response>();
    final api = client(
      (r) async => r.method == 'GET' ? json(dto()) : gate.future,
    );
    addTearDown(api.dispose);
    await login(api);
    await t.pumpWidget(FitCenterAdminApp(api: api));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Chính sách đặt lịch'));
    await t.tap(find.text('Chính sách đặt lịch'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(FilledButton));
    await t.tap(find.byType(FilledButton));
    await t.pump();
    api.logout();
    await t.pumpAndSettle();
    gate.complete(json(dto()));
    await t.pumpAndSettle();
    expect(find.byType(BookingPolicyPage), findsNothing);
    expect(find.byKey(const Key('login')), findsOneWidget);
  });
  testWidgets('non Admin denied at original login', (t) async {
    final api = ApiClient(
      expectedRole: 'ADMIN',
      baseUri: Uri.parse('http://localhost/api/v1'),
      client: MockClient((_) async => tokens('PT')),
    );
    addTearDown(api.dispose);
    await t.pumpWidget(FitCenterAdminApp(api: api));
    await t.enterText(
      find.byKey(const Key('email')),
      'synthetic@example.invalid',
    );
    await t.enterText(find.byKey(const Key('password')), 'test-only');
    await t.ensureVisible(find.byKey(const Key('login')));
    await t.tap(find.byKey(const Key('login')));
    await t.pumpAndSettle();
    expect(api.authenticated, false);
    expect(find.textContaining('ROLE_MISMATCH'), findsOneWidget);
  });
}
