import 'package:flutter/material.dart';

/// Rounded white sheet that keeps a table readable on the backdrop.
const tableRadius = BorderRadius.all(Radius.circular(18));

/// Full grid and a shaded heading, shared by every Admin table.
TableBorder tableGrid(BuildContext context) => TableBorder.all(
  color: Theme.of(context).colorScheme.outlineVariant,
  borderRadius: tableRadius,
);

WidgetStateProperty<Color?> tableHeading(BuildContext context) =>
    WidgetStatePropertyAll(
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
    );

const tableHeadingStyle = TextStyle(fontWeight: FontWeight.w800);
