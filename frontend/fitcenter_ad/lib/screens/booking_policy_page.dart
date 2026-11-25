import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/booking_policy_service.dart';
import '../services/vietnam_time.dart';

class BookingPolicyPage extends StatefulWidget {
  final BookingPolicyService service;
  final VoidCallback onLogout;
  const BookingPolicyPage({
    super.key,
    required this.service,
    required this.onLogout,
  });

  @override
  State<BookingPolicyPage> createState() => _BookingPolicyPageState();
}

class _BookingPolicyPageState extends State<BookingPolicyPage> {
  final _formKey = GlobalKey<FormState>();

  final _daysController = TextEditingController();
  final _noticeHoursController = TextEditingController();
  final _cancelHoursController = TextEditingController();
  final _futureBookingsController = TextEditingController();

  BookingPolicy? _policy;
  bool _loading = true, _saving = false, _readReady = false, _reconcile = false;
  int _readGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _busy => _loading || _saving;
  void _fill(BookingPolicy? policy) {
    final values = policy?.configuration.values.toList() ?? <int>[];
    final controllers = [
      _daysController,
      _noticeHoursController,
      _cancelHoursController,
      _futureBookingsController,
    ];
    for (var i = 0; i < controllers.length; i++) {
      controllers[i].text = values.isEmpty ? '' : values[i].toString();
    }
  }

  Future<void> _load() async {
    if (_saving) return;
    final generation = ++_readGeneration;
    setState(() {
      _loading = true;
      _saveMessage = null;
    });
    try {
      final policy = await widget.service.read();
      if (!mounted || generation != _readGeneration) return;
      setState(() {
        _policy = policy;
        _fill(policy);
        _readReady = true;
        _reconcile = false;
      });
    } on ApiError catch (e) {
      if (mounted && generation == _readGeneration)
        setState(() {
          _readReady = false;
          _saveMessage = e.toString();
        });
    } finally {
      if (mounted && generation == _readGeneration)
        setState(() => _loading = false);
    }
  }

  String? _saveMessage;

  @override
  void dispose() {
    _daysController.dispose();
    _noticeHoursController.dispose();
    _cancelHoursController.dispose();
    _futureBookingsController.dispose();
    super.dispose();
  }

  Future<void> _savePolicy() async {
    if (_busy ||
        !_readReady ||
        _reconcile ||
        !_formKey.currentState!.validate())
      return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    try {
      final policy = await widget.service.save({
        'maxAdvanceDays': int.parse(_daysController.text.trim()),
        'minNoticeHours': int.parse(_noticeHoursController.text.trim()),
        'cancelDeadlineHours': int.parse(_cancelHoursController.text.trim()),
        'maxFutureBookings': int.parse(_futureBookingsController.text.trim()),
      });
      if (!mounted) return;
      setState(() {
        _policy = policy;
        _fill(policy);
        _saveMessage = 'Đã lưu chính sách từ máy chủ.';
      });
    } on ApiError catch (e) {
      if (mounted)
        setState(() {
          _reconcile = e.outcomeUnknown;
          _saveMessage = e.toString();
        });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildNumberField({
    required String title,
    required String label,
    required String suffix,
    required TextEditingController controller,
    required int minimum,
    required String fieldName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(fieldName),
          enabled: !_busy && _readReady && !_reconcile,
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => validatePolicyInteger(value, minimum),
          onChanged: (_) {
            setState(() {
              _saveMessage = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(value, textAlign: TextAlign.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chính sách đặt lịch'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Quy định đặt lịch',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thiết lập thời gian và giới hạn đặt lịch PT.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            if (_busy) const LinearProgressIndicator(),
            if (!_loading && _readReady && _policy == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Chưa cấu hình chính sách. Nhập các giá trị để tạo cấu hình đầu tiên.',
                ),
              ),
            if (_reconcile)
              const Text(
                'Chưa xác định được kết quả lưu. Hãy tải lại chính sách để đối chiếu trước khi lưu tiếp.',
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại chính sách'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNumberField(
                      title: 'Thời gian đặt lịch trước tối đa',
                      label: 'Số ngày',
                      suffix: 'ngày',
                      controller: _daysController,
                      minimum: 1,
                      fieldName: 'Thời gian đặt trước tối đa',
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      title: 'Thời gian báo trước tối thiểu',
                      label: 'Số giờ',
                      suffix: 'giờ',
                      controller: _noticeHoursController,
                      minimum: 0,
                      fieldName: 'Thời gian báo trước tối thiểu',
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      title: 'Thời hạn hủy lịch',
                      label: 'Hủy trước giờ tập',
                      suffix: 'giờ',
                      controller: _cancelHoursController,
                      minimum: 0,
                      fieldName: 'Thời hạn hủy lịch',
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      title: 'Số lịch tương lai tối đa',
                      label: 'Số lịch',
                      suffix: 'lịch',
                      controller: _futureBookingsController,
                      minimum: 1,
                      fieldName: 'Số lịch tương lai tối đa',
                    ),

                    const Divider(height: 32),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: const Text('Ngày bắt đầu áp dụng'),
                      subtitle: Text(
                        _policy == null
                            ? 'Chưa cấu hình'
                            : vietnamTime(_policy!.effectiveFrom),
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Chính sách có hiệu lực ngay khi lưu. Hạn hủy mới áp dụng cho các yêu cầu Member hủy sau cập nhật, kể cả booking đã tạo trước đó. Giảm giới hạn không tự hủy hoặc sửa booking đã có.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chính sách trên máy chủ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildSummaryRow(
                      icon: Icons.calendar_month_outlined,
                      title: 'Đặt trước tối đa',
                      value: _policy == null
                          ? '—'
                          : '${_policy!.maxAdvanceDays} ngày',
                    ),
                    _buildSummaryRow(
                      icon: Icons.access_time,
                      title: 'Báo trước tối thiểu',
                      value: _policy == null
                          ? '—'
                          : '${_policy!.minNoticeHours} giờ',
                    ),
                    _buildSummaryRow(
                      icon: Icons.event_busy_outlined,
                      title: 'Hạn hủy lịch',
                      value: _policy == null
                          ? '—'
                          : '${_policy!.cancelDeadlineHours} giờ',
                    ),
                    _buildSummaryRow(
                      icon: Icons.event_available_outlined,
                      title: 'Số lịch tương lai tối đa',
                      value: _policy == null
                          ? '—'
                          : '${_policy!.maxFutureBookings} lịch',
                    ),
                    _buildSummaryRow(
                      icon: Icons.calendar_today_outlined,
                      title: 'Bắt đầu áp dụng',
                      value: _policy == null
                          ? 'Chưa cấu hình'
                          : vietnamTime(_policy!.effectiveFrom),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_saveMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _saveMessage!.startsWith('Đã lưu')
                      ? Colors.green.withValues(alpha: 0.10)
                      : Colors.orange.withValues(alpha: 0.10),
                ),
                child: Text(_saveMessage!),
              ),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _busy || !_readReady || _reconcile
                  ? null
                  : _savePolicy,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kiểm tra và lưu chính sách'),
            ),
          ],
        ),
      ),
    );
  }
}
