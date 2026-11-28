import 'package:flutter/material.dart';

import '../services/booking_state.dart';
import '../services/booking_models.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import '../widgets/student_info.dart';
import '../widgets/pull_to_reload.dart';

class SessionDetailPage extends StatefulWidget {
  final Map<String, dynamic> session;
  final BookingState state;
  final ValueChanged<Map<String, dynamic>>? onSessionUpdated;

  const SessionDetailPage({
    super.key,
    required this.session,
    required this.state,
    this.onSessionUpdated,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late Map<String, dynamic> _session;
  bool get _isProcessing => widget.state.busy;

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
  }

  @override
  void didUpdateWidget(covariant SessionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.session != widget.session) {
      _session = Map<String, dynamic>.from(widget.session);
    }
  }

  bool get _isConfirmed => _session['status'] == 'CONFIRMED';

  Booking get _booking => _session['dto'] as Booking;

  /// The server only completes a session that has ended, and only lets the
  /// trainer cancel one that has not started. It still has the final say.
  bool get _canComplete =>
      _isConfirmed && !DateTime.now().toUtc().isBefore(_booking.endAt);
  bool get _canCancel =>
      _isConfirmed && DateTime.now().toUtc().isBefore(_booking.startAt);

  String get _statusLabel {
    switch (_session['status']) {
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'COMPLETED':
        return 'Đã hoàn tất';
      default:
        return 'Không xác định';
    }
  }

  Color _statusColor() {
    final colors = Theme.of(context).colorScheme;
    switch (_session['status']) {
      case 'CONFIRMED':
        return const Color(0xFFF57C00);
      case 'CANCELLED':
        return colors.error;
      case 'COMPLETED':
        return const Color(0xFF2E9E44);
      default:
        return colors.outline;
    }
  }

  String get _cancelledBy => switch (_session['cancelledBy']) {
    'PT' => 'bạn',
    'MEMBER' => 'hội viên',
    final other => '$other',
  };

  Future<void> _cancelSession() => widget.state.act(() async {
    var input = '';
    String? error;
    final reason = await showDialog<String>(
      useRootNavigator: false,
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: const Text('Hủy buổi tập'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vui lòng nhập lý do hủy buổi tập.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('cancel-reason'),
                maxLines: 3,
                maxLength: 500,
                onChanged: (s) => input = s,
                decoration: InputDecoration(
                  labelText: 'Lý do hủy',
                  hintText: 'Nhập lý do cụ thể...',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Không hủy'),
            ),
            FilledButton(
              key: const Key('submit-reason'),
              onPressed: () {
                if (input.trim().isEmpty) {
                  change(() => error = 'Bạn phải nhập lý do trước khi hủy.');
                  return;
                }
                Navigator.pop(context, input.trim());
              },
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted || !widget.state.alive) return;
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: Text(
          'Bạn có chắc chắn muốn hủy buổi tập này không?\n\nLý do: $reason\n\nKhung giờ gốc sẽ không tự động mở lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không hủy'),
          ),
          FilledButton(
            key: const Key('confirm-pt-cancel'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && widget.state.alive)
      await widget.state.transition(_session['dto'] as Booking, reason: reason);
  });
  Future<void> _completeSession() => widget.state.act(() async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn tất buổi tập'),
        content: const Text('Xác nhận buổi tập này đã hoàn thành?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            key: const Key('confirm-complete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hoàn tất'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && widget.state.alive)
      await widget.state.transition(_session['dto'] as Booking);
  });
  String _when(DateTime instant) =>
      '${vietnamClock(instant)} ngày ${vietnamDateText(instant)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết buổi tập')),
      bottomNavigationBar: _isConfirmed ? _actions(context) : null,
      body: SafeArea(
        child: PullToReload(
          onReload: () => PullToReload.bookings(widget.state),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              ApiStatus(state: widget.state),
              _studentCard(context),
              const SizedBox(height: 12),
              _sessionCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  TextStyle _muted(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontSize: 13.5,
    height: 1.4,
  );

  Widget _studentCard(BuildContext context) => _card(context, [
    StudentInfo(api: widget.state.service.api, session: _session),
  ]);

  /// When it is and where it stands.
  Widget _sessionCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final day = vietnamDate(_booking.startAt);
    final weekday = const [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ][day.weekday - 1];
    final reason = _session['cancellationReason'];
    return _card(context, [
      Row(
        children: [
          Expanded(
            child: Text(
              '$weekday, ${vietnamDateText(_booking.startAt)}',
              style: _muted(context),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _statusColor(),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        '${_session['start'] ?? '--:--'} - ${_session['end'] ?? '--:--'}',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      if (_session['completedAt'] != null) ...[
        const SizedBox(height: 6),
        Text(
          'Hoàn tất lúc: ${_session['completedAt']}',
          style: _muted(context),
        ),
      ],
      if (_session['cancelledAt'] != null) ...[
        const SizedBox(height: 6),
        Text(
          'Hủy bởi $_cancelledBy lúc ${_session['cancelledAt']}',
          style: _muted(context),
        ),
      ],
      if (_session['status'] == 'CANCELLED' && reason != null) ...[
        Divider(height: 24, color: colors.outlineVariant),
        Text('Lý do hủy', style: _muted(context)),
        Text('$reason', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ]);
  }

  /// Only for a confirmed session, and kept on screen.
  Widget _actions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hint = _canComplete
        ? null
        : 'Hoàn tất được sau ${_when(_booking.endAt)}.';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null) ...[
              Text(hint, textAlign: TextAlign.center, style: _muted(context)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: const Key('complete'),
              onPressed: widget.state.blocked || !_canComplete
                  ? null
                  : _completeSession,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                _isProcessing ? 'Đang xử lý...' : 'Hoàn tất buổi tập',
              ),
            ),
            if (_canCancel) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('pt-cancel'),
                onPressed: widget.state.blocked ? null : _cancelSession,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Hủy buổi tập'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
