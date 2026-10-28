import 'package:flutter/material.dart';

class SessionDetailPage extends StatefulWidget {
  final Map<String, dynamic> session;
  final ValueChanged<Map<String, dynamic>>? onSessionUpdated;

  const SessionDetailPage({
    super.key,
    required this.session,
    this.onSessionUpdated,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late Map<String, dynamic> _session;
  bool _isProcessing = false;

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

  DateTime? _parseSessionDateTime(String key) {
    final date = _session['date'];
    final time = _session[key];

    if (date is! DateTime || time is! String) {
      return null;
    }

    final parts = time.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  bool get _isConfirmed => _session['status'] == 'CONFIRMED';

  bool get _canComplete {
    final endDateTime = _parseSessionDateTime('end');

    return _isConfirmed &&
        endDateTime != null &&
        !DateTime.now().isBefore(endDateTime);
  }

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _cancelSession() async {
    if (!_isConfirmed || _isProcessing) return;

    final reasonController = TextEditingController();
    String? errorMessage;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Hủy buổi tập'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vui lòng nhập lý do hủy buổi tập. '
                          'Thông tin này cần được lưu cùng booking.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Lý do hủy',
                        hintText: 'Nhập lý do cụ thể...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setDialogState(() {
                            errorMessage = null;
                          });
                        }
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Quay lại'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () {
                    final input = reasonController.text.trim();

                    if (input.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                        'Bạn phải nhập lý do trước khi hủy.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, input);
                  },
                  child: const Text('Tiếp tục'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận hủy'),
          content: Text(
            'Bạn có chắc chắn muốn hủy buổi tập này không?\n\n'
                'Lý do: $reason\n\n'
                'Khung giờ gốc sẽ không tự động mở lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Không hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Dữ liệu demo: cập nhật trạng thái trên giao diện.
      // Khi tích hợp backend, thay đoạn này bằng API hủy booking.
      setState(() {
        _session['status'] = 'CANCELLED';
        _session['cancellationReason'] = reason;
      });

      widget.onSessionUpdated?.call(
        Map<String, dynamic>.from(_session),
      );

      _showMessage('Đã hủy buổi tập.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _completeSession() async {
    if (!_isConfirmed || _isProcessing) return;

    if (!_canComplete) {
      _showMessage(
        'Chỉ có thể hoàn tất buổi tập sau khi thời gian tập kết thúc.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hoàn tất buổi tập'),
          content: const Text(
            'Xác nhận buổi tập này đã hoàn thành?\n\n'
                'Sau khi hoàn tất, trạng thái booking sẽ chuyển '
                'sang COMPLETED.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận hoàn tất'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Dữ liệu demo: cập nhật trạng thái trên giao diện.
      // Khi tích hợp backend, thay đoạn này bằng API hoàn tất booking.
      setState(() {
        _session['status'] = 'COMPLETED';
      });

      widget.onSessionUpdated?.call(
        Map<String, dynamic>.from(_session),
      );

      _showMessage('Đã hoàn tất buổi tập.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = _session['date'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết buổi tập'),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
                  const Icon(
                    Icons.event_note,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Thông tin buổi tập',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
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

            const SizedBox(height: 24),

            if (_isConfirmed) ...[
              const Text(
                'Thao tác',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing || !_canComplete
                      ? null
                      : _completeSession,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isProcessing
                        ? 'Đang xử lý...'
                        : 'Hoàn tất buổi tập',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (!_canComplete && !_isProcessing) ...[
                const SizedBox(height: 8),
                Text(
                  'Nút hoàn tất sẽ khả dụng sau khi buổi tập kết thúc.',
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
                  onPressed: _isProcessing ? null : _cancelSession,
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
              'Trạng thái hiện được cập nhật bằng dữ liệu mẫu '
                  'trên giao diện, chưa được lưu lên backend.',
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

  Widget _buildInfoRow(
      BuildContext context,
      String label,
      String value,
      ) {
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
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
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
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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