import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/payment_simulator_service.dart';
import '../services/renewal_models.dart';

class PaymentSimulatorPage extends StatefulWidget {
  final PaymentSimulatorService service;
  const PaymentSimulatorPage({super.key, required this.service});
  @override
  State<PaymentSimulatorPage> createState() => _PaymentSimulatorPageState();
}

class _PaymentSimulatorPageState extends State<PaymentSimulatorPage> {
  late final int epoch = widget.service.api.sessionEpoch;
  List<RenewalPayment> rows = [];
  String? error, pendingId;
  Map<String, dynamic>? pending;
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
        rows = [];
        pending = null;
        pendingId = null;
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
      final list = await widget.service.list();
      List<Map<String, dynamic>> events = [];
      if (pendingId != null) events = await widget.service.events(pendingId!);
      if (!current || request != ticket) return;
      setState(() {
        rows = list;
        reconciled = true;
        if (pending != null &&
            events.any((e) => e['eventId'] == pending!['eventId'])) {
          pending = null;
          pendingId = null;
          uncertain = false;
        }
      });
    } catch (e) {
      if (current && request == ticket) setState(() => error = e.toString());
    } finally {
      if (current && request == ticket) setState(() => loading = false);
    }
  }

  Future<void> confirm(RenewalPayment p, String state) async {
    if (!current || busy || loading || pending != null) return;
    setState(() => busy = true);
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận thanh toán mô phỏng'),
        content: Text(
          'Giao dịch ${p.id}\n${paymentDecimal(p.cents)} VNĐ • Kết quả $state\nĐây là mô phỏng, không thu tiền thật. SUCCESS chỉ cấp quyền nếu máy chủ xác nhận đủ điều kiện.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận mô phỏng'),
          ),
        ],
      ),
    );
    if (!current) return;
    if (yes != true) {
      setState(() => busy = false);
      return;
    }
    pendingId = p.id;
    pending = widget.service.command(p, state, newPaymentKey());
    setState(() => busy = false);
    await send();
  }

  Future<void> send() async {
    if (!current || busy || pending == null || pendingId == null) return;
    setState(() {
      busy = true;
      error = null;
      reconciled = false;
    });
    try {
      await widget.service.send(pendingId!, pending!);
      if (current)
        setState(() {
          pending = null;
          pendingId = null;
          uncertain = false;
        });
    } on ApiError catch (e) {
      if (current)
        setState(() {
          error = e.toString();
          uncertain = e.outcomeUnknown || e.status == 0 || e.status >= 500;
          if (!uncertain) {
            pending = null;
            pendingId = null;
          }
        });
    } finally {
      if (current) setState(() => busy = false);
    }
    if (current && pending == null) {
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
        title: const Text('Thanh toán mô phỏng'),
        actions: [
          IconButton(
            tooltip: 'Tải lại giao dịch',
            onPressed: busy || loading ? null : load,
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
              'Chỉ dùng trong môi trường dev/test. Không thu tiền thật.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Kết quả do ADMIN gửi và máy chủ xử lý. SUCCESS cần đối soát không tự mở khóa Membership hoặc cấp kỳ sử dụng.',
            ),
            if (loading)
              const LinearProgressIndicator(key: Key('simulator-loading')),
            if (error != null)
              Text(
                error!,
                key: const Key('simulator-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (uncertain)
              const Text(
                'Chưa rõ kết quả. Tải lại giao dịch và sự kiện để đối chiếu trước khi thử lại cùng yêu cầu.',
              ),
            if (uncertain && pending != null)
              TextButton(
                key: const Key('simulator-retry'),
                onPressed: busy || loading || !reconciled ? null : send,
                child: const Text('Thử lại cùng kết quả'),
              ),
            if (!loading && rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có giao dịch gia hạn.'),
              ),
            for (final p in rows)
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'Mã giao dịch: ${p.id}',
                child: Card(
                  key: ValueKey('simulator-${p.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText('Mã giao dịch: ${p.id}'),
                        Text('Member: ${p.memberId}'),
                        Text('Membership: ${p.membershipId}'),
                        Text(
                          '${p.planName} • ${p.days} ngày • ${paymentDecimal(p.cents)} VNĐ',
                        ),
                        Text(p.statusLabel),
                        Text(p.fulfillmentLabel),
                        if (p.reason != null)
                          Text('Lý do đối soát: ${p.reason}'),
                        if (p.start != null && p.end != null)
                          Text(
                            '${showPaidDate(p.start!)} – ${showPaidDate(p.end!)}',
                          ),
                        if (p.status == 'PENDING')
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final state in [
                                'SUCCESS',
                                'FAILED',
                                'CANCELLED',
                              ])
                                FilledButton(
                                  key: ValueKey('${p.id}-$state'),
                                  onPressed: busy || loading || pending != null
                                      ? null
                                      : () => confirm(p, state),
                                  child: Text('Mô phỏng $state'),
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
