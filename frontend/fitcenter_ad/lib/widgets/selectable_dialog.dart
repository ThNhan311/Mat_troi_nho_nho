import 'package:flutter/material.dart';

/// Flutter paints text itself, so it can only be highlighted and copied inside a
/// [SelectionArea]. Pages get one from the theme; dialogs open through here.
Future<T?> showSelectableDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  barrierDismissible: barrierDismissible,
  builder: (_) => SelectionArea(child: Builder(builder: builder)),
);
