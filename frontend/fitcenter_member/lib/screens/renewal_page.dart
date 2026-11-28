import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/renewal_service.dart';
import '../services/renewal_models.dart';
import '../widgets/pull_to_reload.dart';
import '../widgets/record_card.dart';
import '../widgets/renewal_confirm_dialog.dart';
import 'transfer_dialog.dart';

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

  Future<void> pay(RenewalPayment payment) async {
    if (!current || busy || loading) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (_) => TransferDialog(service: widget.service, payment: payment),
    );
    // It may have been confirmed while the dialog was open.
    if (current) await load();
  }

  Future<void> create() async {
    if (!current || busy || loading || pendingKey != null || planId == null)
      return;
    final chosen = plans.where((p) => p.id == planId).first;
    setState(() => busy = true);
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => RenewalConfirmDialog(
        planName: chosen.name,
        days: chosen.days,
        cents: chosen.cents,
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
    RenewalPayment? unpaid;
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
      if (p.status == 'PENDING' && p.cents > 0) unpaid = p;
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
    // A new unpaid transaction goes straight to the payment screen, which
    // reloads this page when it is closed.
    if (current && unpaid != null) {
      await pay(unpaid);
      return;
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
      appBar: AppBar(title: const Text('Gia hạn Membership')),
      body: PullToReload(
        onReload: () async {
          if (!loading && !busy) await load();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thanh toán chuyển khoản',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              if (loading)
                const LinearProgressIndicator(key: Key('renewal-loading')),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    key: const Key('renewal-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
              // A title above the field, so nothing sits on its border.
              const Text(
                'Chọn gói gia hạn',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('renewal-plan-$planId'),
                initialValue: planId,
                // Shown while nothing is chosen.
                hint: const Text('Chưa chọn gói gia hạn'),
                disabledHint: const Text('Chưa chọn gói gia hạn'),
                isExpanded: true,
                items: plans
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name} • ${p.days} ngày • ${paymentMoney(p.cents)}',
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
                onPressed:
                    busy || loading || pendingKey != null || planId == null
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
                RecordCard(
                  icon: Icons.event_available_outlined,
                  title: p.phaseLabel,
                  rows: [
                    RecordRow('Gói', p.name ?? 'Kỳ tổng hợp từ dữ liệu cũ'),
                    RecordRow('Từ ngày', showPaidDate(p.start)),
                    RecordRow('Đến ngày', showPaidDate(p.end)),
                    if (p.cents != null) ...[
                      RecordRow('Thời hạn', '${p.days} ngày'),
                      RecordRow(
                        'Số tiền',
                        paymentMoney(p.cents!),
                        strong: true,
                      ),
                    ],
                    RecordRow('Mã kỳ', shortCode(p.id)),
                    RecordRow('Mã gói', shortCode(p.planId)),
                  ],
                  note: p.source == 'LEGACY_AGGREGATE'
                      ? 'Dữ liệu cũ tổng hợp; chưa có snapshot giá và lịch sử từng lần mua.'
                      : null,
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
                  label: 'Mã giao dịch: ${shortCode(p.id)}',
                  child: RecordCard(
                    key: ValueKey('payment-${p.id}'),
                    icon: Icons.receipt_long_outlined,
                    title: 'Giao dịch ${shortCode(p.id)}',
                    rows: [
                      RecordRow('Gói', p.planName),
                      RecordRow('Thời hạn', '${p.days} ngày'),
                      RecordRow('Số tiền', paymentMoney(p.cents), strong: true),
                      RecordRow('Trạng thái', p.statusLabel),
                      RecordRow('Kỳ sử dụng', p.fulfillmentLabel),
                      if (p.start != null && p.end != null) ...[
                        RecordRow('Từ ngày', showPaidDate(p.start!)),
                        RecordRow('Đến ngày', showPaidDate(p.end!)),
                      ],
                      if (p.reason != null)
                        RecordRow('Lý do đối soát', p.reason!),
                      RecordRow('Ngày tạo', paymentTime(p.createdAt)),
                    ],
                    action: p.status == 'PENDING' && p.cents > 0
                        ? FilledButton.icon(
                            key: ValueKey('pay-${p.id}'),
                            onPressed: busy || loading ? null : () => pay(p),
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Thanh toán bằng mã QR'),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
