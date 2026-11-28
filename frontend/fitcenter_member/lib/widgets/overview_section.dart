import 'package:flutter/material.dart';

import '../services/booking_models.dart';
import '../services/booking_state.dart';
import '../services/membership_service.dart';
import '../services/vietnam_time.dart';
import 'info_card.dart';

/// The package worth showing: usable today first, then whatever needs attention.
Membership? mainMembership(List<Membership> rows, DateTime today) {
  int rank(Membership row) {
    final start = _day(row.startDate), end = _day(row.endDate);
    if (row.status == 'ACTIVE') {
      if (end != null && end.isBefore(today)) return 4;
      return start != null && start.isAfter(today) ? 1 : 0;
    }
    return const {
          'PENDING_ACTIVATION': 2,
          'SUSPENDED': 3,
          'EXPIRED': 4,
        }[row.status] ??
        5;
  }

  final shown = rows.where((row) => row.status != 'CANCELLED').toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : (b.endDate ?? '').compareTo(a.endDate ?? '');
    });
  return shown.firstOrNull;
}

DateTime? _day(String? value) =>
    value == null ? null : DateTime.tryParse('${value}T00:00:00Z');

/// Home overview built only from server data; a failed read never shows zero.
class OverviewSection extends StatefulWidget {
  const OverviewSection({
    super.key,
    required this.state,
    required this.active,
    required this.onOpenSchedule,
    required this.onOpenMembership,
  });

  final BookingState state;

  /// Whether the home tab is on screen.
  final bool active;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMembership;

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  List<Membership>? _memberships;
  List<DateTime>? _checkins;
  bool _membershipFailed = false, _checkinFailed = false;
  bool _started = false;
  bool _wasLoading = false;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    // Listening directly catches a reload that ends before the next frame.
    widget.state.addListener(_onState);
    _sync(false);
  }

  @override
  void didUpdateWidget(OverviewSection old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
    }
    if (widget.active && !old.active) _sync(true);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() => _sync(false);

  /// Reads after the bookings finish, so an expired session is already renewed.
  void _sync(bool returned) {
    final state = widget.state;
    final ready = state.loaded && !state.loading && state.alive;
    if (ready && (!_started || _wasLoading || returned)) {
      _started = true;
      _load();
    }
    _wasLoading = state.loading;
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    final api = widget.state.service.api;
    final epoch = api.sessionEpoch;
    bool current() => mounted && ticket == _ticket && epoch == api.sessionEpoch;

    Future<void> memberships() async {
      try {
        final rows = items(
          await api.peek('/memberships/me'),
          Membership.fromJson,
        );
        if (current()) {
          setState(() {
            _memberships = rows;
            _membershipFailed = false;
          });
        }
      } catch (_) {
        if (current()) {
          setState(() {
            _memberships = null;
            _membershipFailed = true;
          });
        }
      }
    }

    Future<void> checkins() async {
      final today = vietnamDate(DateTime.now().toUtc());
      // Midnight in Vietnam is 17:00 UTC of the previous day.
      DateTime monthStart(int month) =>
          DateTime.utc(today.year, month).subtract(const Duration(hours: 7));
      try {
        final rows = items(
          await api.peek(
            '/attendance/me',
            query: queryRange(
              monthStart(today.month),
              monthStart(today.month + 1),
            ),
          ),
          (row) => instant(row, 'checkedInAt'),
        );
        if (current()) {
          setState(() {
            _checkins = [...rows]..sort((a, b) => b.compareTo(a));
            _checkinFailed = false;
          });
        }
      } catch (_) {
        if (current()) {
          setState(() {
            _checkins = null;
            _checkinFailed = true;
          });
        }
      }
    }

    await Future.wait([memberships(), checkins()]);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final upcoming = widget.state.loaded
        ? (widget.state.bookings
              .where((b) => b.status == 'CONFIRMED' && b.endAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt)))
        : null;
    final checkins = _checkins;
    final last = checkins?.firstOrNull;
    return Column(
      children: [
        _membershipCard(context),
        const SizedBox(height: 12),
        _nextSessionCard(context, upcoming),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: InfoCard(
                  key: const Key('overview-checkins'),
                  icon: Icons.how_to_reg_outlined,
                  title: 'Check-in tháng này',
                  value: checkins == null ? '—' : '${checkins.length} lần',
                  subtitle: _checkinFailed
                      ? 'Chưa tải được'
                      : checkins == null
                      ? 'Đang tải'
                      : last == null
                      ? 'Chưa check-in'
                      : 'Gần nhất ${_shortDay(last)} ${vietnamClock(last)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InfoCard(
                  key: const Key('overview-bookings'),
                  icon: Icons.event_available_outlined,
                  title: 'Lịch PT đã đặt',
                  value: upcoming == null ? '—' : '${upcoming.length} buổi',
                  subtitle: 'Sắp tới',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _shortDay(DateTime instant) =>
      vietnamDateText(instant).substring(0, 5);

  Widget _membershipCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = _memberships;
    final today = vietnamDate(DateTime.now().toUtc());
    final row = rows == null ? null : mainMembership(rows, today);

    var title = 'Đang tải gói tập';
    var detail = '';
    double? remaining;
    if (_membershipFailed) {
      title = 'Chưa tải được gói tập';
      detail = 'Bấm để xem trang gói hội viên.';
    } else if (rows != null && row == null) {
      title = 'Chưa đăng ký gói';
      detail = 'Liên hệ phòng tập để đăng ký.';
    } else if (row != null) {
      title = row.planName;
      final start = _day(row.startDate), end = _day(row.endDate);
      final until = end == null
          ? ''
          : 'Hết hạn ${Membership.displayDate(row.endDate)}';
      if (row.status != 'ACTIVE') {
        detail = row.statusLabel;
      } else if (start != null && start.isAfter(today)) {
        detail = 'Bắt đầu từ ${Membership.displayDate(row.startDate)}';
      } else if (end == null) {
        detail = row.statusLabel;
      } else {
        final left = end.difference(today).inDays;
        detail = left < 0
            ? 'Đã hết hạn • $until'
            : left == 0
            ? 'Hết hạn hôm nay'
            : 'Còn $left ngày • $until';
        if (start != null && left >= 0) {
          final total = end.difference(start).inDays;
          if (total > 0) remaining = (left / total).clamp(0.0, 1.0);
        }
      }
    }

    return _OverviewCard(
      key: const Key('overview-membership'),
      icon: Icons.card_membership,
      label: 'Gói tập',
      // There is nothing to renew until a package exists.
      action: row == null ? null : 'Gia hạn',
      onTap: widget.onOpenMembership,
      value: row == null ? null : title,
      children: [
        if (row == null)
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ],
        if (remaining != null) ...[
          const SizedBox(height: 12),
          // The filled part is the time still left.
          LinearProgressIndicator(
            value: remaining,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ],
    );
  }

  Widget _nextSessionCard(BuildContext context, List<Booking>? upcoming) {
    final colors = Theme.of(context).colorScheme;
    final next = upcoming?.firstOrNull;
    const strong = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
    final muted = TextStyle(color: colors.onSurfaceVariant, fontSize: 13);
    return _OverviewCard(
      key: const Key('overview-next'),
      icon: Icons.schedule,
      label: 'Buổi PT sắp tới',
      onTap: widget.onOpenSchedule,
      children: [
        if (upcoming == null)
          const Text('—', style: strong)
        else if (next == null) ...[
          const Text('Chưa có lịch sắp tới', style: strong),
          const SizedBox(height: 4),
          Text('Bấm để đặt lịch với PT.', style: muted),
        ] else ...[
          Text(
            '${_weekday(next.startAt)}, ${_shortDay(next.startAt)}\n'
            '${vietnamClock(next.startAt)} - ${vietnamClock(next.endAt)}',
            style: strong,
          ),
          const SizedBox(height: 4),
          Text('Với ${widget.state.trainerName(next.ptId)}', style: muted),
        ],
      ],
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

/// Full-width tappable card with a round icon and a small label.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.children,
    this.action,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Widget> children;

  /// Short words shown just before the arrow.
  final String? action;

  /// Shown in bold on the same line as the label.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
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
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Only the first line shares its width with the arrow.
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: label,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              children: [
                                if (value != null)
                                  TextSpan(
                                    text: '  $value',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (action != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              action!,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
