import 'package:flutter_test/flutter_test.dart';
import 'package:fitcenter/main.dart';

void main() {
  testWidgets('FitCenter app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const FitCenterApp());

    expect(find.text('Trang chủ'), findsOneWidget);
  });
}