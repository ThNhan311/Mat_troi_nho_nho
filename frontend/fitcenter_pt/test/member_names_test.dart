import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fitcenter_pt/services/api_client.dart';

import 'original_ui_test.dart' show auth, enter, tap;
import 'widget_test.dart' as f;

ApiClient client(Object? Function() names, {int status = 200}) => ApiClient(
  expectedRole: 'PT',
  baseUri: Uri.parse('http://localhost/api/v1'),
  client: MockClient((r) async {
    final path = r.url.path;
    if (path.endsWith('/login')) return f.json(auth());
    if (path.endsWith('/pt/booked-members')) {
      return f.json(names() ?? {}, status);
    }
    return f.json(path.endsWith('/bookings') ? [f.booking()] : []);
  }),
);

void main() {
  testWidgets('cards and detail use the name the server gives', (t) async {
    final api = client(
      () => [
        {'memberId': f.memberId, 'fullName': 'Tran Thi Hoa'},
      ],
    );
    addTearDown(api.dispose);
    await enter(t, api);
    await tap(t, find.text('Buổi tập').last);
    expect(find.text('Tran Thi Hoa'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('session-${f.bookingId}')));
    expect(find.text('Tran Thi Hoa'), findsOneWidget);
    expect(find.text('Mã hội viên: 40000000'), findsOneWidget);
  });

  // A name is decoration: failing to read it must not hide bookings or end
  // the session.
  for (final status in [401, 500]) {
    testWidgets('a $status on names falls back to the code', (t) async {
      final api = client(() => null, status: status);
      addTearDown(api.dispose);
      await enter(t, api);
      await tap(t, find.text('Buổi tập').last);
      expect(find.text('Học viên 40000000'), findsOneWidget);
      expect(api.authenticated, isTrue);
    });
  }
}
