import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scrolls the visible page to the top, then pulls it down to reload.
Future<void> pullToReload(WidgetTester t) async {
  final page = find.byType(RefreshIndicator).hitTestable().first;
  t
      .state<ScrollableState>(
        find.descendant(of: page, matching: find.byType(Scrollable)).first,
      )
      .position
      .jumpTo(0);
  await t.pump();
  await t.fling(page, const Offset(0, 400), 1000);
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  await t.pumpAndSettle();
}
