import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/membership_plan_service.dart';

class MembershipPage extends StatefulWidget {
  final MembershipPlanService service;
  final VoidCallback onLogout;
  const MembershipPage({
    super.key,
    required this.service,
    required this.onLogout,
  });
  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  List<MembershipPlan> _plans = [];
  bool _loading = true, _dialog = false;
  String? _error, _createdId;
  int _read = 0;
  late final int _epoch = widget.service.api.sessionEpoch;
  bool get _current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == _epoch;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final read = ++_read;
    if (_current)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final plans = await widget.service.list();
      if (_current && read == _read)
        setState(() {
          _plans = plans;
          _loading = false;
        });
    } on ApiError catch (e) {
      if (_current && read == _read)
        setState(() {
          _plans = [];
          _loading = false;
          _error = e.toString();
        });
    }
  }

  void _unavailable() =>
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chưa khả dụng')));
  Future<void> _add() async {
    if (_dialog || !_current) return;
    setState(() => _dialog = true);
    final plan = await showDialog<MembershipPlan>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => _CreatePlanDialog(service: widget.service, reload: _load),
    );
    if (!mounted || !_current) return;
    setState(() {
      _dialog = false;
      if (plan != null) _createdId = plan.id;
    });
    if (plan != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm gói tập từ máy chủ. Mã gói: ${plan.id}'),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), primary = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý gói tập',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _dialog || _loading || _error != null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Thêm gói'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text(
              'MEMBERSHIP PLANS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các gói hội viên',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Các gói đang hoạt động. Thời hạn tính bằng ngày.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_createdId != null)
              SelectableText('Mã gói vừa tạo: $_createdId'),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!, key: const Key('plan-error')),
              TextButton(onPressed: _load, child: const Text('Thử tải lại')),
            ],
            if (!_loading && _error == null && _plans.isEmpty)
              const Text('Chưa có gói tập đang hoạt động.'),
            ..._plans.map(
              (plan) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.card_membership_outlined,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              plan.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sửa gói — Chưa khả dụng',
                            onPressed: _unavailable,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Xóa gói — Chưa khả dụng',
                            onPressed: _unavailable,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${decimalPrice(plan.cents)} đ',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Thời hạn: ${plan.durationDays} ngày'),
                      if (plan.description != null) Text(plan.description!),
                      SelectableText('Mã gói: ${plan.id}'),
                      const Divider(height: 28),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 19,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Đang hoạt động',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Tooltip(
                            message: 'Đổi trạng thái — Chưa khả dụng',
                            child: Switch(
                              value: true,
                              onChanged: (_) => _unavailable(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlanDialog extends StatefulWidget {
  final MembershipPlanService service;
  final Future<void> Function() reload;
  const _CreatePlanDialog({required this.service, required this.reload});
  @override
  State<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<_CreatePlanDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _price = TextEditingController(),
      _days = TextEditingController();
  bool _sending = false, _unknown = false;
  String? _error;
  late final int _epoch = widget.service.api.sessionEpoch;
  bool get _current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == _epoch;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_sending || _unknown || !_current || !_form.currentState!.validate())
      return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final plan = await widget.service.create(
        name: _name.text,
        description: _description.text.isEmpty ? null : _description.text,
        durationDays: int.parse(_days.text.trim()),
        cents: priceCents(_price.text)!,
      );
      if (mounted && _current) Navigator.pop(context, plan);
    } on ApiError catch (e) {
      if (_current)
        setState(() {
          _sending = false;
          _unknown = e.outcomeUnknown;
          _error =
              '${e.toString()}${_unknown ? '\nChưa xác định được kết quả tạo. Tải lại danh sách để đối chiếu; không gửi lại. Tên gói có thể trùng nên không dùng tên để xác nhận gói vừa tạo.' : ''}';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: const Text('Thêm gói tập'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_sending && !_unknown,
                  decoration: const InputDecoration(labelText: 'Tên gói tập'),
                  validator: validatePlanName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  enabled: !_sending && !_unknown,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Giá (VNĐ)'),
                  validator: validatePlanPrice,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _days,
                  enabled: !_sending && !_unknown,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời hạn (ngày)',
                  ),
                  validator: validateDurationDays,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  enabled: !_sending && !_unknown,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả (tùy chọn)',
                  ),
                  validator: (v) => v != null && v.contains('\u0000')
                      ? 'Mô tả không được chứa ký tự rỗng.'
                      : null,
                ),
                if (_sending) const CircularProgressIndicator(),
                if (_error != null) Text(_error!),
                if (_unknown)
                  TextButton(
                    onPressed: () async {
                      await widget.reload();
                    },
                    child: const Text('Tải lại danh sách để đối chiếu'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(_unknown ? 'Đóng' : 'Hủy'),
        ),
        FilledButton(
          onPressed: _sending || _unknown ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
}
