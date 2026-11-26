import 'package:flutter/material.dart';

import 'desktop_shell.dart';

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

  void _say(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit(MembershipPlan plan) async {
    if (_dialog || !_current) return;
    setState(() => _dialog = true);
    final saved = await showDialog<MembershipPlan>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => _CreatePlanDialog(
        service: widget.service,
        reload: _load,
        editing: plan,
      ),
    );
    if (!mounted || !_current) return;
    setState(() => _dialog = false);
    if (saved != null) _say('Đã lưu gói ${saved.name}.');
    await _load();
  }

  Future<void> _delete(MembershipPlan plan) async {
    if (_dialog || !_current) return;
    setState(() => _dialog = true);
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa gói tập'),
        content: SizedBox(
          width: 420,
          child: Text(
            'Xóa gói "${plan.name}"? Nếu đã có người mua, gói chỉ ngừng bán và '
            'ẩn khỏi danh sách; gói của họ giữ nguyên.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-plan-delete'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || !_current) return;
    setState(() => _dialog = false);
    if (yes != true) return;
    try {
      final archived = await widget.service.delete(plan.id);
      _say(
        archived ? 'Gói đã có người mua nên chỉ ngừng bán.' : 'Đã xóa gói tập.',
      );
    } on ApiError catch (e) {
      _say(e.toString());
    }
    if (_current) {
      if (_createdId == plan.id) setState(() => _createdId = null);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), primary = theme.colorScheme.primary;
    final desktop = AdminDesktopScope.isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          desktop ? 'Gói tập' : 'Quản lý gói tập',
          style: desktop ? null : const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (desktop)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _dialog || _loading || _error != null ? null : _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm gói'),
              ),
            ),
          IconButton(
            tooltip: 'Tải lại danh sách',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (!AdminDesktopScope.isDesktop(context))
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      floatingActionButton: desktop
          ? null
          : FloatingActionButton.extended(
              onPressed: _dialog || _loading || _error != null ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('Thêm gói'),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            if (!desktop) ...[
              const Text(
                'Các gói hội viên',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
            ],
            Text('Các gói đang hoạt động.', style: theme.textTheme.bodyMedium),
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
            _PlanGrid(
              children: [
                for (final plan in _plans)
                  Card(
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
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            moneyText(plan.cents),
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Thời hạn: ${durationText(plan.durationDays)}'),
                          if (plan.description != null) Text(plan.description!),
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
                              IconButton(
                                key: ValueKey('edit-plan-${plan.id}'),
                                tooltip: 'Sửa gói',
                                onPressed: _dialog ? null : () => _edit(plan),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              IconButton(
                                key: ValueKey('delete-plan-${plan.id}'),
                                tooltip: 'Xóa gói',
                                onPressed: _dialog ? null : () => _delete(plan),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One column on narrow windows, two or three side by side on wide ones.
class _PlanGrid extends StatelessWidget {
  final List<Widget> children;
  const _PlanGrid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 1000
          ? 3
          : box.maxWidth >= 820
          ? 2
          : 1;
      final width = (box.maxWidth - 14 * (columns - 1)) / columns;
      return Wrap(
        spacing: 14,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _CreatePlanDialog extends StatefulWidget {
  final MembershipPlanService service;
  final Future<void> Function() reload;
  final MembershipPlan? editing;
  const _CreatePlanDialog({
    required this.service,
    required this.reload,
    this.editing,
  });
  @override
  State<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<_CreatePlanDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name),
      _description = TextEditingController(text: widget.editing?.description),
      _price = TextEditingController(text: _priceText(widget.editing?.cents)),
      _days = TextEditingController(
        text: widget.editing == null
            ? null
            : '${widget.editing!.durationDays ~/ _unit.days}',
      );
  late DurationUnit _unit = widget.editing == null
      ? DurationUnit.day
      : DurationUnit.of(widget.editing!.durationDays);
  static String? _priceText(int? cents) => cents == null
      ? null
      : cents % 100 == 0
      ? '${cents ~/ 100}'
      : decimalPrice(cents);
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
      final name = _name.text,
          description = _description.text.isEmpty ? null : _description.text,
          days = int.parse(_days.text.trim()) * _unit.days,
          cents = priceCents(_price.text)!;
      final plan = widget.editing == null
          ? await widget.service.create(
              name: name,
              description: description,
              durationDays: days,
              cents: cents,
            )
          : await widget.service.update(
              widget.editing!.id,
              name: name,
              description: description,
              durationDays: days,
              cents: cents,
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
      title: Text(widget.editing == null ? 'Thêm gói tập' : 'Sửa gói tập'),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _days,
                        enabled: !_sending && !_unknown,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thời hạn',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => validateDuration(v, _unit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<DurationUnit>(
                        key: const Key('plan-unit'),
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Đơn vị'),
                        items: [
                          for (final unit in DurationUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: _sending || _unknown
                            ? null
                            : (v) {
                                if (v != null) setState(() => _unit = v);
                              },
                      ),
                    ),
                  ],
                ),
                if (_unit != DurationUnit.day &&
                    validateDuration(_days.text, _unit) == null)
                  Text(
                    '= ${int.parse(_days.text.trim()) * _unit.days} ngày '
                    '(1 tháng tính 30 ngày, 1 năm tính 365 ngày)',
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
