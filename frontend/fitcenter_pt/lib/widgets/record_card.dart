import 'package:flutter/material.dart';

/// One labelled line of a record: what it is, then its value.
class RecordRow {
  const RecordRow(this.label, this.value, {this.strong = false});

  final String label, value;

  /// For the amount, which people look for first.
  final bool strong;
}

/// Full-width card listing a record as "label — value" lines.
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.icon,
    required this.title,
    required this.rows,
    this.note,
    this.action,
  });

  final IconData icon;
  final String title;
  final List<RecordRow> rows;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: row.strong ? colors.primary : colors.onSurface,
                        fontSize: row.strong ? 16 : 13.5,
                        fontWeight: row.strong
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note != null)
            Text(
              note!,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}
