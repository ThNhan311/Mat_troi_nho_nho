import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitcenter_pt/screens/trainer_profile_page.dart';
import 'package:fitcenter_pt/services/api_client.dart';

import 'original_ui_test.dart' show auth, enter, tap;
import 'widget_test.dart' as f;

Map<String, dynamic> profile({
  String? bio,
  String? specialization,
  String? experience,
}) => {
  'id': f.ptId,
  'fullName': 'Trainer',
  'bio': bio,
  'specialization': specialization,
  'experienceSummary': experience,
};

/// Signs in and opens the editor from the profile tab.
Future<ApiClient> open(
  WidgetTester t,
  Future<http.Response> Function(http.Request) onProfile,
) async {
  final api = ApiClient(
    expectedRole: 'PT',
    baseUri: Uri.parse('http://localhost/api/v1'),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/login')) return f.json(auth());
      if (path.endsWith('/pt/profile')) return onProfile(r);
      return f.json([]);
    }),
  );
  addTearDown(api.dispose);
  await enter(t, api);
  await tap(t, find.text('Cá nhân').last);
  await tap(t, find.text('Hồ sơ huấn luyện viên'));
  expect(find.byType(TrainerProfilePage), findsOneWidget);
  return api;
}

bool selected(WidgetTester t, String choice) =>
    t.widget<FilterChip>(find.widgetWithText(FilterChip, choice)).selected;

String typed(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  testWidgets('shows the saved profile and sends the chosen specialties', (
    t,
  ) async {
    final writes = <Map<String, dynamic>>[];
    await open(t, (r) async {
      if (r.method == 'GET') {
        return f.json(profile(specialization: 'yoga, Kettlebell'));
      }
      expect(r.method, 'PUT');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      writes.add(body);
      return f.json({...profile(), ...body});
    });
    expect(selected(t, 'Yoga'), isTrue);
    expect(selected(t, 'Tăng cơ'), isFalse);
    expect(typed(t, 'profile-other'), 'Kettlebell');

    await tap(t, find.widgetWithText(FilterChip, 'Tăng cơ'));
    await t.enterText(find.byKey(const Key('profile-experience')), ' 3 nam ');
    await t.enterText(find.byKey(const Key('profile-bio')), 'Xin chao');
    await tap(t, find.byKey(const Key('profile-save')));

    expect(writes.single, {
      'bio': 'Xin chao',
      'specialization': 'Tăng cơ, Yoga, Kettlebell',
      'experienceSummary': '3 nam',
    });
    expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
  });

  testWidgets('a failed read offers no way to overwrite the profile', (
    t,
  ) async {
    var reads = 0;
    await open(t, (r) async {
      expect(r.method, 'GET');
      return ++reads == 1 ? f.json({}, 500) : f.json(profile(bio: 'Da co'));
    });
    expect(find.byKey(const Key('profile-save')), findsNothing);
    expect(find.byKey(const Key('profile-bio')), findsNothing);
    await tap(t, find.byKey(const Key('profile-reload')));
    expect(typed(t, 'profile-bio'), 'Da co');
    expect(find.byKey(const Key('profile-save')), findsOneWidget);
  });

  testWidgets('an unclear save is not sent twice', (t) async {
    var writes = 0;
    final api = await open(t, (r) async {
      if (r.method == 'GET') return f.json(profile());
      writes++;
      throw http.ClientException('offline');
    });
    await tap(t, find.byKey(const Key('profile-save')));
    expect(writes, 1);
    expect(find.byKey(const Key('profile-save')), findsNothing);
    expect(find.byKey(const Key('profile-reload')), findsOneWidget);
    expect(api.authenticated, isTrue);
  });

  testWidgets('too many specialties are stopped before sending', (t) async {
    var writes = 0;
    await open(t, (r) async {
      if (r.method == 'GET') return f.json(profile());
      writes++;
      return f.json(profile());
    });
    await tap(t, find.widgetWithText(FilterChip, 'Yoga'));
    await t.enterText(find.byKey(const Key('profile-other')), 'x' * 200);
    await tap(t, find.byKey(const Key('profile-save')));
    expect(writes, 0);
    expect(find.textContaining('Chuyên môn quá dài'), findsOneWidget);
  });
}
