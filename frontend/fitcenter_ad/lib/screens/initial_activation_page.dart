import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/admin_account_service.dart';
import '../services/membership_plan_service.dart';
import '../services/initial_activation_service.dart';
import '../services/vietnam_time.dart';

class InitialActivationPage extends StatefulWidget {
  final InitialActivationService service;
  const InitialActivationPage({super.key, required this.service});
  @override
  State<InitialActivationPage> createState() => _InitialActivationPageState();
}

class _InitialActivationPageState extends State<InitialActivationPage> {
  final form = GlobalKey<FormState>(),
      receipt = TextEditingController(),
      note = TextEditingController();
  List<AdminAccount> members = [];
  List<MembershipPlan> plans = [];
  String? memberId, planId, error, key;
  Map<String, dynamic>? pending;
  InitialActivation? result;
  bool loading = true,
      busy = false,
      sending = false,
      confirmed = false,
      uncertain = false,
      reconciled = false;
  late final int epoch = widget.service.api.sessionEpoch;
  bool get current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == epoch;
  bool get locked => busy || pending != null || result != null;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    receipt.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!current) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final m = await widget.service.members(),
          p = await widget.service.plans();
      if (current)
        setState(() {
          members = m;
          plans = p;
          loading = false;
        });
    } catch (e) {
      if (current)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  MembershipPlan? get selected =>
      plans.where((p) => p.id == planId).firstOrNull;
  String preview() {
    try {
      final p = selected;
      if (p == null) return 'Chọn gói để xem ngày dự kiến.';
      final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
      final start = DateTime.utc(vn.year, vn.month, vn.day),
          end = start.add(Duration(days: p.durationDays - 1));
      return '${showCalendar(start.toIso8601String().substring(0, 10))} – ${showCalendar(end.toIso8601String().substring(0, 10))} (dự kiến, giờ Việt Nam)';
    } catch (_) {
      return 'Ngày thực tế sẽ do máy chủ xác định.';
    }
  }

  Future<void> submit() async {
    if (!current ||
        locked ||
        !form.currentState!.validate() ||
        selected == null ||
        memberId == null)
      return;
    if (!confirmed) {
      setState(() => error = 'Vui lòng xác nhận đã thu tiền tại quầy.');
      return;
    }
    setState(() => busy = true);
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận kích hoạt Membership'),
        content: Text(
          'Ghi nhận ${decimalPrice(selected!.cents)} VNĐ đã thu tại quầy. Thao tác không kích hoạt tài khoản đăng nhập.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận đã thu tiền'),
          ),
        ],
      ),
    );
    if (!current) return;
    if (yes != true) {
      setState(() => busy = false);
      return;
    }
    key = newActivationKey();
    pending = {
      'planId': planId,
      'amountCollected': num.parse(decimalPrice(selected!.cents)),
      'receiptRef': receipt.text.trim(),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
    };
    await send();
  }

  Future<void> send() async {
    if (!current || sending || pending == null || memberId == null) return;
    sending = true;
    setState(() {
      busy = true;
      error = null;
      reconciled = false;
    });
    try {
      final row = await widget.service.create(memberId!, key!, pending!);
      if (current)
        setState(() {
          result = row;
          uncertain = false;
        });
    } on ApiError catch (e) {
      if (current)
        setState(() {
          error = e.toString();
          uncertain = e.outcomeUnknown || e.status == 0 || e.status >= 500;
        });
    } finally {
      sending = false;
      if (current) setState(() => busy = false);
    }
  }

  Future<void> read() async {
    if (!current || busy || memberId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final row = await widget.service.read(memberId!);
      if (current)
        setState(() {
          result = row;
          uncertain = false;
          reconciled = true;
        });
    } on ApiError catch (e) {
      if (current)
        setState(() {
          error = e.status == 404
              ? 'Chưa thấy bản ghi đã hoàn tất. Yêu cầu trước có thể vẫn đang xử lý; không tạo yêu cầu mới.'
              : e.toString();
          reconciled = true;
        });
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kích hoạt Gói hội viên')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Kích hoạt hội viên lần đầu',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chọn Member đã tồn tại, chọn gói và ghi nhận khoản đã thu tại quầy. Tạo tài khoản là thao tác riêng.',
          ),
          const SizedBox(height: 20),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              key: const Key('initial-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (!loading && members.isEmpty)
            const Text(
              'Chưa có Member. Tạo tài khoản tại Hội viên & PT trước.',
            ),
          if (!loading && plans.isEmpty) const Text('Chưa có gói ACTIVE.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Thông tin Member',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const Key('initial-member'),
                      initialValue: memberId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn Member đã tồn tại',
                        border: OutlineInputBorder(),
                      ),
                      items: members
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.profileId,
                              child: Text(
                                '${m.fullName} • ${m.profileId}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: locked
                          ? null
                          : (v) => setState(() {
                              memberId = v;
                              result = null;
                              error = null;
                            }),
                      validator: (v) => v == null ? 'Chọn Member' : null,
                    ),
                    if (memberId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Tài khoản: ${members.firstWhere((m) => m.profileId == memberId).statusLabel}. Kích hoạt gói không đổi trạng thái đăng nhập.',
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      '2. Gói hội viên',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('initial-plan'),
                      initialValue: planId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn gói hội viên',
                        border: OutlineInputBorder(),
                      ),
                      items: plans
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name} • ${p.durationDays} ngày • ${decimalPrice(p.cents)} VNĐ',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: locked
                          ? null
                          : (v) => setState(() => planId = v),
                      validator: (v) => v == null ? 'Chọn gói' : null,
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 12),
                      Text('Số tiền: ${decimalPrice(selected!.cents)} VNĐ'),
                      Text(preview()),
                      const Text(
                        'Ngày và giá áp dụng do máy chủ xác nhận. Không nhập ngày hoặc giảm giá.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      '3. Xác nhận thanh toán trực tiếp',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Thanh toán offline đã hoàn tất'),
                      subtitle: const Text(
                        'Chỉ ghi nhận khoản đã thu; không thực hiện thu tiền qua ngân hàng.',
                      ),
                      onChanged: locked
                          ? null
                          : (v) => setState(() => confirmed = v ?? false),
                    ),
                    TextFormField(
                      key: const Key('initial-receipt'),
                      controller: receipt,
                      enabled: !locked,
                      decoration: const InputDecoration(
                        labelText: 'Mã chứng từ tại quầy',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null ||
                              v.trim().isEmpty ||
                              v.runes.length > 100 ||
                              v.contains('\u0000')
                          ? 'Nhập mã chứng từ không rỗng, tối đa 100 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('initial-note'),
                      controller: note,
                      enabled: !locked,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v != null &&
                              (v.runes.length > 500 || v.contains('\u0000'))
                          ? 'Ghi chú tối đa 500 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('initial-submit'),
                      onPressed: locked || loading ? null : submit,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Kích hoạt Gói hội viên'),
                    ),
                    OutlinedButton(
                      key: const Key('initial-read'),
                      onPressed: busy || memberId == null ? null : read,
                      child: const Text('Đọc kết quả đã ghi nhận'),
                    ),
                    if (pending != null && result == null) ...[
                      const Text(
                        'Đối chiếu kết quả trước khi thử lại. Không gửi yêu cầu mới khi kết quả chưa rõ.',
                      ),
                      OutlinedButton(
                        key: const Key('initial-retry'),
                        onPressed: busy || !reconciled ? null : send,
                        child: const Text('Thử lại cùng yêu cầu'),
                      ),
                      if (!uncertain)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () {
                                  setState(() {
                                    pending = null;
                                    key = null;
                                    error = null;
                                    confirmed = false;
                                  });
                                  load();
                                },
                          child: const Text(
                            'Chọn yêu cầu khác sau lỗi đã xác định',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (result != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4. Trạng thái Gói hội viên',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Đã ghi nhận kích hoạt Membership ACTIVE'),
                    Text(result!.planName),
                    Text(
                      '${showCalendar(result!.startDate)} – ${showCalendar(result!.endDate)}',
                    ),
                    Text('Thực thu: ${decimalPrice(result!.cents)} VNĐ'),
                    Text('Chứng từ: ${result!.receiptRef}'),
                    Text('Ghi nhận: ${vietnamTime(result!.confirmedAt)}'),
                    const Text('Mã Membership'),
                    Semantics(
                      label: 'Mã Membership: ${result!.membershipId}',
                      child: SelectableText(result!.membershipId),
                    ),
                    const Text('Mã giao dịch'),
                    Semantics(
                      label: 'Mã giao dịch: ${result!.paymentId}',
                      child: SelectableText(result!.paymentId),
                    ),
                    const Text(
                      'Đây là bản ghi lúc kích hoạt. Tài khoản đăng nhập không thay đổi. Gia hạn và Face: Chưa khả dụng.',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
