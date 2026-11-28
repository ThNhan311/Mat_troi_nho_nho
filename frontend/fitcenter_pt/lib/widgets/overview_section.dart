import 'package:flutter/material.dart';

import '../services/booking_models.dart';
import '../services/booking_state.dart';
import '../services/vietnam_time.dart';
import 'info_card.dart';

/// Home overview built only from the bookings the server returned.
class OverviewSection extends StatelessWidget {
  const OverviewSection({
    super.key,
    required this.state,
    required this.onOpenSessions,
    required this.onOpenSchedule,
    this.sessionCount,
    this.memberCount,
  });

  final BookingState state;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenSchedule;

  /// Null until the server has answered, so zero is never made up.
  final int? sessionCount, memberCount;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final upcoming = state.loaded
        ? (state.bookings
              .where((b) => b.status == 'CONFIRMED' && b.endAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt)))
        : null;
    return Column(
      children: [
        _nextSessionCard(context, upcoming),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: InfoCard(
                  key: const Key('overview-sessions'),
                  icon: Icons.event_available_outlined,
                  title: 'Buổi tập hôm nay',
                  value: sessionCount == null ? '—' : '$sessionCount buổi',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InfoCard(
                  key: const Key('overview-members'),
                  icon: Icons.people_outline,
                  title: 'Học viên hôm nay',
                  value: memberCount == null ? '—' : '$memberCount người',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nextSessionCard(BuildContext context, List<Booking>? upcoming) {
    final colors = Theme.of(context).colorScheme;
    final next = upcoming?.firstOrNull;
    const strong = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
    final muted = TextStyle(color: colors.onSurfaceVariant, fontSize: 13);
    return Material(
      key: const Key('overview-next'),
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: upcoming != null && next == null
            ? onOpenSchedule
            : onOpenSessions,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Buổi dạy sắp tới',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (upcoming == null)
                      const Text('—', style: strong)
                    else if (next == null) ...[
                      const Text('Chưa có lịch sắp tới', style: strong),
                      const SizedBox(height: 4),
                      Text('Bấm để xem lịch làm.', style: muted),
                    ] else ...[
                      Text(
                        '${_weekday(next.startAt)}, '
                        '${vietnamDateText(next.startAt).substring(0, 5)}\n'
                        '${vietnamClock(next.startAt)} - '
                        '${vietnamClock(next.endAt)}',
                        style: strong,
                      ),
                      const SizedBox(height: 4),
                      Text('${state.session(next)['memberName']}', style: muted),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _weekday(DateTime instant) => const [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ][vietnamDate(instant).weekday - 1];
}
