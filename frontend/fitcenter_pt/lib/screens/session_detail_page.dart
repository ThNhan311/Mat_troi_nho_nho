import 'package:flutter/material.dart';

import '../services/booking_state.dart';
import '../services/booking_models.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';

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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  bool get _isConfirmed => _session['status'] == 'CONFIRMED';
  bool get _canComplete => _isConfirmed;

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
    switch (_session['status']) {
      case 'CONFIRMED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.redAccent;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

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
                  border: const OutlineInputBorder(),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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
  Future<void> _eligibility() => widget.state.act(() async {
    final result = await widget.state.service.eligibility(
      _session['dto'] as Booking,
    );
    if (!mounted || !widget.state.alive) return;
    await showDialog<void>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.eligible
              ? 'Đủ điều kiện tại thời điểm kiểm tra'
              : 'Chưa đủ điều kiện',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kiểm tra lúc: ${vietnamTime(result.checkedAt)}\nUTC: ${result.checkedAt.toIso8601String()}',
            ),
            ...result.reasonCodes.map(
              (code) => Text('${eligibilityReason(code)} [$code]'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kết quả chỉ phản ánh thời điểm kiểm tra và có thể thay đổi. Không ghi nhận bắt đầu buổi tập.',
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('close-eligibility'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = _session['date'];

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết buổi tập')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ApiStatus(state: widget.state),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_note, size: 36),
                  const SizedBox(height: 16),
                  const Text(
                    'Thông tin buổi tập',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    context,
                    'Mã booking',
                    '${_session['id'] ?? 'Chưa có'}',
                  ),
                  _buildInfoRow(
                    context,
                    'Học viên',
                    '${_session['memberName'] ?? 'Chưa có'}',
                  ),
                  _buildInfoRow(
                    context,
                    'Ngày tập',
                    date is DateTime ? _formatDate(date) : 'Chưa có',
                  ),
                  _buildInfoRow(
                    context,
                    'Thời gian',
                    '${_session['start'] ?? '--:--'}'
                        ' - '
                        '${_session['end'] ?? '--:--'}',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Row(
                      children: [
                        const Text(
                          'Trạng thái',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
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
                  ),
                ],
              ),
            ),

            if (_session['status'] == 'CANCELLED' &&
                _session['cancellationReason'] != null) ...[
              const SizedBox(height: 20),
              _buildNoticeCard(
                context,
                title: 'Lý do hủy',
                message: '${_session['cancellationReason']}',
                icon: Icons.info_outline,
                color: Colors.redAccent,
              ),
            ],

            if (_session['completedAt'] != null)
              Text('Hoàn tất lúc: ${_session['completedAt']}'),
            if (_session['cancelledAt'] != null)
              Text(
                'Hủy bởi ${_session['cancelledBy']} lúc ${_session['cancelledAt']}',
              ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              key: const Key('eligibility'),
              onPressed: widget.state.blocked ? null : _eligibility,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Kiểm tra điều kiện'),
            ),
            if (_isConfirmed) ...[
              const Text(
                'Thao tác',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('complete'),
                  onPressed: widget.state.blocked || !_canComplete
                      ? null
                      : _completeSession,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isProcessing ? 'Đang xử lý...' : 'Hoàn tất buổi tập',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (!_canComplete && !_isProcessing) ...[
                const SizedBox(height: 8),
                Text(
                  'Hệ thống chỉ cho phép hoàn tất khi buổi tập đã kết thúc.',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('pt-cancel'),
                  onPressed: widget.state.blocked ? null : _cancelSession,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Hủy buổi tập'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ] else
              _buildNoticeCard(
                context,
                title: 'Không thể thao tác',
                message: _session['status'] == 'COMPLETED'
                    ? 'Buổi tập đã hoàn tất. Không thể hủy hoặc hoàn tất lại.'
                    : 'Buổi tập đã bị hủy. Không thể thực hiện thao tác trên booking này.',
                icon: Icons.lock_outline,
                color: Colors.grey,
              ),

            const SizedBox(height: 16),
            Text(
              'Giờ Việt Nam (UTC+07:00).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.65)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
