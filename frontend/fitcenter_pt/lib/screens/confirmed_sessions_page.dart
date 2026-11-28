import 'package:flutter/material.dart';

import '../services/booking_models.dart';
import '../services/booking_state.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import '../widgets/brand_logo.dart';
import '../widgets/pull_to_reload.dart';

enum _Tab { upcoming, done, cancelled }

/// The trainer's sessions: what is coming, what was taught and what was
/// cancelled, grouped by day.
class ConfirmedSessionsPage extends StatefulWidget {
  final BookingState state;
  final void Function(Map<String, dynamic> session) onOpenSession;

  const ConfirmedSessionsPage({
    super.key,
    required this.onOpenSession,
    required this.state,
  });

  @override
  State<ConfirmedSessionsPage> createState() => _ConfirmedSessionsPageState();
}

class _ConfirmedSessionsPageState extends State<ConfirmedSessionsPage> {
  static const _orange = Color(0xFFF57C00);
  static const _green = Color(0xFF2E9E44);

  _Tab _tab = _Tab.upcoming;

  List<Booking> _with(String status, {bool newestFirst = false}) {
    final rows = widget.state.bookings.where((b) => b.status == status).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return newestFirst ? rows.reversed.toList() : rows;
  }

  static String _dayName(DateTime day) {
    final today = vietnamDate(DateTime.now().toUtc());
    final date =
        '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}';
    final offset = day.difference(today).inDays;
    final name = switch (offset) {
      0 => 'Hôm nay',
      1 => 'Ngày mai',
      -1 => 'Hôm qua',
      _ => const [
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy',
        'Chủ nhật',
      ][day.weekday - 1],
    };
    return '$name, $date';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now().toUtc();
    final confirmed = _with('CONFIRMED');
    // Ended but not marked complete: only the trainer can close these.
    final overdue = confirmed.where((b) => !b.endAt.isAfter(now)).toList();
    final upcoming = confirmed.where((b) => b.endAt.isAfter(now)).toList();
    final rows = switch (_tab) {
      _Tab.upcoming => upcoming,
      _Tab.done => _with('COMPLETED', newestFirst: true),
      _Tab.cancelled => _with('CANCELLED', newestFirst: true),
    };
    final waiting = _tab == _Tab.upcoming ? overdue : const <Booking>[];

    return Scaffold(
      body: SafeArea(
        child: PullToReload(
          onReload: () => PullToReload.bookings(widget.state),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ApiStatus(state: widget.state),
              // The logo shares the title's line.
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Buổi tập',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  BrandLogo(width: 100),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Theo dõi lịch tập với học viên',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Tab>(
                  showSelectedIcon: false,
                  segments: [
                    _segment(_Tab.upcoming, 'Sắp tới', confirmed.length),
                    _segment(_Tab.done, 'Đã dạy'),
                    _segment(_Tab.cancelled, 'Đã hủy'),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (chosen) =>
                      setState(() => _tab = chosen.first),
                ),
              ),
              if (_tab != _Tab.upcoming) ...[
                const SizedBox(height: 10),
                Text(
                  'Hiện các buổi trong ${BookingState.historyDays} ngày qua.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (waiting.isNotEmpty) ...[
                _heading('Cần hoàn tất (${waiting.length})', color: _orange),
                for (final booking in waiting)
                  _card(context, booking, showDay: true),
              ],
              ..._byDay(context, rows),
              if (rows.isEmpty && waiting.isEmpty && widget.state.loaded)
                _empty(context),
            ],
          ),
        ),
      ),
    );
  }

  ButtonSegment<_Tab> _segment(_Tab tab, String label, [int count = 0]) =>
      ButtonSegment(
        value: tab,
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(count > 0 ? '$label ($count)' : label),
        ),
      );

  Widget _heading(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );

  List<Widget> _byDay(BuildContext context, List<Booking> rows) {
    final widgets = <Widget>[];
    DateTime? current;
    for (final booking in rows) {
      final day = vietnamDate(booking.startAt);
      if (day != current) {
        current = day;
        widgets.add(_heading(_dayName(day)));
      }
      widgets.add(_card(context, booking));
    }
    return widgets;
  }

  /// One session: the hours, a status line in its colour, then the student.
  Widget _card(BuildContext context, Booking booking, {bool showDay = false}) {
    final colors = Theme.of(context).colorScheme;
    final session = widget.state.session(booking);
    final name = session['memberName'] as String;
    final start = session['start'] as String;
    final end = session['end'] as String;
    final now = DateTime.now().toUtc();
    final (Color tone, String note) = switch (booking.status) {
      'COMPLETED' => (_green, 'Đã hoàn tất'),
      'CANCELLED' => (colors.error, _cancelNote(booking)),
      _ when !booking.endAt.isAfter(now) => (
        _orange,
        showDay
            ? '${_dayName(vietnamDate(booking.startAt))} · Chờ bạn hoàn tất'
            : 'Chờ bạn hoàn tất',
      ),
      _ when !booking.startAt.isAfter(now) => (_orange, 'Đang diễn ra'),
      _ => (_orange, 'Đã xác nhận'),
    };
    final open = widget.state.busy ? null : () => widget.onOpenSession(session);

    return Semantics(
      label:
          'Buổi tập ${booking.id}. $name. '
          '${vietnamDateText(booking.startAt)}. $start - $end. $note',
      button: true,
      excludeSemantics: true,
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          key: ValueKey('session-${booking.id}'),
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            start,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            end,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tone,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _cancelNote(Booking booking) {
    final who = switch (booking.cancelledBy) {
      'PT' => 'Bạn đã hủy',
      'MEMBER' => 'Học viên hủy',
      _ => 'Đã hủy',
    };
    final reason = booking.cancelReason?.trim() ?? '';
    return reason.isEmpty ? who : '$who: $reason';
  }

  Widget _empty(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        switch (_tab) {
          _Tab.upcoming => 'Chưa có buổi tập sắp tới.',
          _Tab.done => 'Chưa có buổi nào đã dạy.',
          _Tab.cancelled => 'Không có buổi nào bị hủy.',
        },
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
    );
  }
}
