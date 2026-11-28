import 'package:flutter/material.dart';

/// The month grid of the member app: arrows, weekdays, dots under each day and
/// a legend.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.marksOf,
    required this.legend,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
    this.note,
  });

  /// Days are UTC midnights that name a Vietnam calendar day.
  final DateTime month, today;
  final DateTime? selected;
  final List<Color> Function(DateTime day) marksOf;
  final List<(Color, String)> legend;
  final VoidCallback onPrevious, onNext;
  final ValueChanged<DateTime> onSelect;

  /// Shown under the legend, for a month that could not be read in full.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    // Monday is the first column.
    final blank = DateTime.utc(month.year, month.month).weekday - 1;
    final cells = ((blank + days) / 7).ceil() * 7;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('previous-month'),
                tooltip: 'Tháng trước',
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left, color: colors.onSurface),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Tháng ${month.month} ${month.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('next-month'),
                tooltip: 'Tháng sau',
                onPressed: onNext,
                icon: Icon(Icons.chevron_right, color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final number = index - blank + 1;
              if (number < 1 || number > days) return const SizedBox();
              return _day(
                context,
                DateTime.utc(month.year, month.month, number),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final (color, text) in legend)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (note case final text?) ...[
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _day(BuildContext context, DateTime date) {
    final colors = Theme.of(context).colorScheme;
    final isPast = date.isBefore(today);
    final isToday = date == today;
    final isSelected = date == selected;
    return GestureDetector(
      key: ValueKey('day-${date.year}-${date.month}-${date.day}'),
      onTap: () => onSelect(date),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : isToday
              ? colors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: colors.primary)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected
                    ? colors.onPrimary
                    : isPast
                    ? colors.onSurface.withValues(alpha: 0.3)
                    : colors.onSurface,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final mark in marksOf(date))
                    Container(
                      key: ValueKey('mark-${date.day}-${mark.toARGB32()}'),
                      width: isSelected ? 8 : 6,
                      height: isSelected ? 8 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: mark,
                        shape: BoxShape.circle,
                        // A light ring keeps dots visible on the selected day.
                        border: isSelected
                            ? Border.all(color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
