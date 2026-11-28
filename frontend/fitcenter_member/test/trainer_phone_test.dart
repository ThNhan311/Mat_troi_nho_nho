import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcenter/screens/trainer_detail_page.dart';
import 'package:fitcenter/services/booking_models.dart';

Future<void> show(WidgetTester t, String? phone) async {
  await t.binding.setSurfaceSize(const Size(400, 1000));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    MaterialApp(
      home: TrainerDetailPage(
        trainerName: 'Coach',
        phone: phone,
        specialization: 'Yoga',
        experience: '3 years',
        gender: 'MALE',
        onShowMessage: (_) {},
        onBookAppointment: () {},
      ),
    ),
  );
}

void main() {
  test('the phone from the server is optional', () {
    const id = '10000000-0000-0000-0000-000000000001';
    expect(
      Trainer.fromJson({'id': id, 'fullName': 'A', 'phone': '0901234567'})
          .phone,
      '0901234567',
    );
    expect(Trainer.fromJson({'id': id, 'fullName': 'A'}).phone, isNull);
  });

  testWidgets('shows the trainer phone and copies it', (t) async {
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await show(t, '0901234567');
    expect(find.text('Nam'), findsOneWidget);
    expect(find.text('Kinh nghiệm: 3 years'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    await t.tap(find.byKey(const Key('copy-phone')));
    await t.pump();
    expect(copied, ['0901234567']);
    expect(find.text('Đã sao chép số điện thoại.'), findsOneWidget);
  });

  testWidgets('a trainer without a number says so and has nothing to copy', (
    t,
  ) async {
    await show(t, null);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.byKey(const Key('copy-phone')), findsNothing);
  });
}
