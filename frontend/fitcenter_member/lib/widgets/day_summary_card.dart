import 'package:flutter/material.dart';

/// One thing that happened, or is booked, on the chosen day.
class DayEntry {
  const DayEntry({
    required this.at,
    required this.color,
    required this.title,
    this.detail,
  });

  /// Entries are listed in this order.
  final DateTime at;

  /// The same colour as the calendar legend.
  final Color color;
  final String title;
  final String? detail;
}

/// What the calendar day holds, one line per event.
class DaySummaryCard extends StatelessWidget {
  const DaySummaryCard({
    super.key,
    required this.date,
    required this.entries,
    required this.emptyText,
    this.badge,
    this.note,
  });

  final String date;

  /// "Hôm nay", when it is.
  final String? badge;
  final List<DayEntry> entries;

  /// Said when there is nothing, which must really be known.
  final String? emptyText;

  /// Loading, or a day that could not be read in full.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13,
      height: 1.4,
    );
    final sorted = [...entries]..sort((a, b) => a.at.compareTo(b.at));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badge case final text?)
                Text(
                  text,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (index, entry) in sorted.indexed) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (entry.detail case final text?)
                          Text(text, style: muted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (sorted.isEmpty && emptyText != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(emptyText!, style: muted),
            ),
          if (note case final text?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(text, style: muted),
            ),
        ],
      ),
    );
  }
}
