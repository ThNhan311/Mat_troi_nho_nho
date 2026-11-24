import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/renewal_service.dart';
import '../services/renewal_models.dart';

class RenewalPage extends StatefulWidget {
  final RenewalService service;
  final String membershipId;
  const RenewalPage({
    super.key,
    required this.service,
    required this.membershipId,
  });
  @override
  State<RenewalPage> createState() => _RenewalPageState();
}

class _RenewalPageState extends State<RenewalPage> {
  late final int epoch = widget.service.api.sessionEpoch;
  List<RenewalPlan> plans = [];
  List<PaidPeriod> periods = [];
  List<RenewalPayment> payments = [];
  String? planId, error, pendingKey, pendingPlan;
  RenewalPayment? result;
  bool loading = true, busy = false, uncertain = false, reconciled = false;
  int ticket = 0;
  bool get current =>
      mounted &&
      widget.service.api.authenticated &&
      widget.service.api.sessionEpoch == epoch;
  @override
  void initState() {
    super.initState();
    widget.service.api.addListener(sessionChanged);
    load();
  }

  void sessionChanged() {
    if (!current && mounted)
      setState(() {
        ticket++;
        plans = [];
        periods = [];
        payments = [];
        result = null;
        pendingKey = null;
        pendingPlan = null;
        error = null;
      });
  }

  @override
  void dispose() {
    ticket++;
    widget.service.api.removeListener(sessionChanged);
    super.dispose();
  }

  Future<void> load() async {
    if (!current || busy) return;
    final request = ++ticket;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final p = await widget.service.plans(),
          h = await widget.service.periods(widget.membershipId),
          all = await widget.service.payments();
      if (!current || request != ticket) return;
      setState(() {
        plans = p;
        periods = h;
        payments = all
            .where((x) => x.membershipId == widget.membershipId)
            .toList();
        reconciled = true;
        final known = payments
            .where((x) => x.requestId == pendingKey)
            .firstOrNull;
        if (known != null) {
          result = known;
          pendingKey = null;
          pendingPlan = null;
          uncertain = false;
        }
        if (!plans.any((x) => x.id == planId) && pendingKey == null)
          planId = null;
      });
    } catch (e) {
      if (current && request == ticket) setState(() => error = e.toString());
    } finally {
      if (current && request == ticket) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    if (!current || busy || loading || pendingKey != null || planId == null)
      return;
    final chosen = plans.where((p) => p.id == planId).first;
    setState(() => busy = true);
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (c) => AlertDialog(
        title: const Text('Tạo giao dịch gia hạn mới'),
        content: Text(
          '${chosen.name} • ${chosen.days} ngày • ${paymentDecimal(chosen.cents)} VNĐ. Giao dịch chờ kết quả thanh toán mô phỏng; chưa cộng thời hạn. Giá và thời lượng được máy chủ chốt khi tạo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tạo giao dịch'),
          ),
        ],
      ),
    );
    if (!current) return;
    if (yes != true) {
      setState(() => busy = false);
      return;
    }
    pendingKey = newPaymentKey();
    pendingPlan = chosen.id;
    setState(() => busy = false);
    await send();
  }

  Future<void> send() async {
    if (!current || busy || pendingKey == null || pendingPlan == null) return;
    setState(() {
      busy = true;
      error = null;
      reconciled = false;
    });
    try {
      final p = await widget.service.create(
        widget.membershipId,
        pendingPlan!,
        pendingKey!,
      );
      if (current)
        setState(() {
          result = p;
          pendingKey = null;
          pendingPlan = null;
          uncertain = false;
        });
    } on ApiError catch (e) {
      if (current)
        setState(() {
          error = e.toString();
          uncertain = e.outcomeUnknown || e.status == 0 || e.status >= 500;
          if (!uncertain) {
            pendingKey = null;
            pendingPlan = null;
          }
        });
    } finally {
      if (current) setState(() => busy = false);
    }
    if (current && pendingKey == null) {
      final failure = error;
      await load();
      if (current && failure != null) setState(() => error = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!current) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gia hạn Membership'),
        actions: [
          IconButton(
            tooltip: 'Tải lại gia hạn',
            onPressed: loading || busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thanh toán mô phỏng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Text(
              'Không thu tiền thật. Chỉ kết quả từ máy chủ mới cấp kỳ sử dụng. Gói khác chỉ áp dụng cho kỳ gia hạn.',
            ),
            const SizedBox(height: 8),
            SelectableText('Mã hội viên: ${widget.membershipId}'),
            if (loading)
              const LinearProgressIndicator(key: Key('renewal-loading')),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  key: const Key('renewal-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (uncertain)
              const Text(
                'Chưa rõ kết quả. Hãy tải lại để đối chiếu trước khi thử lại cùng yêu cầu. Không tạo giao dịch khác thay cho yêu cầu này.',
              ),
            if (uncertain && pendingKey != null)
              TextButton(
                key: const Key('renewal-retry'),
                onPressed: busy || loading || !reconciled ? null : send,
                child: const Text('Thử lại cùng yêu cầu'),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('renewal-plan-$planId'),
              initialValue: planId,
              decoration: const InputDecoration(labelText: 'Chọn gói gia hạn'),
              isExpanded: true,
              items: plans
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} • ${p.days} ngày • ${paymentDecimal(p.cents)} VNĐ',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy || loading || pendingKey != null
                  ? null
                  : (v) => setState(() => planId = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('renewal-create'),
              onPressed: busy || loading || pendingKey != null || planId == null
                  ? null
                  : create,
              child: Text(busy ? 'Đang gửi…' : 'Tạo giao dịch gia hạn mới'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Kỳ sử dụng đã thanh toán',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (!loading && periods.isEmpty)
              const Text('Chưa có kỳ sử dụng được xác minh.'),
            for (final p in periods)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.phaseLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(p.name ?? 'Kỳ tổng hợp từ dữ liệu cũ'),
                      Text(
                        '${showPaidDate(p.start)} – ${showPaidDate(p.end)} (ngày Việt Nam)',
                      ),
                      if (p.cents != null)
                        Text(
                          '${paymentDecimal(p.cents!)} VNĐ • ${p.days} ngày',
                        ),
                      if (p.source == 'LEGACY_AGGREGATE')
                        const Text(
                          'Dữ liệu cũ tổng hợp; chưa có snapshot giá và lịch sử từng lần mua.',
                        ),
                      SelectableText('Mã kỳ: ${p.id}'),
                      Text('Mã gói: ${p.planId}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Giao dịch gia hạn',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (!loading && payments.isEmpty)
              const Text('Chưa có giao dịch gia hạn.'),
            for (final p in payments)
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'Mã giao dịch: ${p.id}',
                child: Card(
                  key: ValueKey('payment-${p.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.planName),
                        SelectableText('Mã giao dịch: ${p.id}'),
                        Text('${paymentDecimal(p.cents)} VNĐ • ${p.days} ngày'),
                        Text(p.statusLabel),
                        Text(p.fulfillmentLabel),
                        if (p.reason != null)
                          Text('Lý do đối soát: ${p.reason}'),
                        if (p.start != null && p.end != null)
                          Text(
                            '${showPaidDate(p.start!)} – ${showPaidDate(p.end!)}',
                          ),
                        Text(paymentTime(p.createdAt)),
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
