import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcenter_ad/main.dart';
import 'package:fitcenter_ad/theme/app_theme.dart';
import 'package:fitcenter_ad/widgets/selectable_dialog.dart';

List<String> clipboard(WidgetTester t) {
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
  return copied;
}

/// Highlights the text with the mouse and presses Ctrl+C.
Future<void> dragAndCopy(WidgetTester t, Finder text) async {
  final box = t.getRect(text);
  final mouse = await t.startGesture(
    box.centerLeft + const Offset(1, 0),
    kind: PointerDeviceKind.mouse,
  );
  await t.pump();
  await mouse.moveTo(box.centerRight + const Offset(4, 0));
  await t.pump();
  await mouse.up();
  await t.pumpAndSettle();
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyC);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('page text can be highlighted and copied', (t) async {
    final copied = clipboard(t);
    await t.pumpWidget(const FitCenterAdminApp());
    await t.pumpAndSettle();
    await dragAndCopy(t, find.text('Quản trị FitCenter'));
    expect(copied.last, 'Quản trị FitCenter');
  });

  testWidgets('dialog text can be highlighted and copied', (t) async {
    final copied = clipboard(t);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSelectableDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('0901234567')),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await dragAndCopy(t, find.text('0901234567'));
    expect(copied.last, '0901234567');
  });
}
