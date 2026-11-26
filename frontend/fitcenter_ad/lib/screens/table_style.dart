import 'package:flutter/material.dart';

/// Full grid and a shaded heading, shared by every Admin table.
TableBorder tableGrid(BuildContext context) => TableBorder.all(
  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.55),
);

WidgetStateProperty<Color?> tableHeading(BuildContext context) =>
    WidgetStatePropertyAll(
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
    );

const tableHeadingStyle = TextStyle(fontWeight: FontWeight.w800);
