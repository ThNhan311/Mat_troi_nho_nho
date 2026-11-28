import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/payment_simulator_service.dart';
import '../services/renewal_models.dart';
import 'transfer_info.dart';
import '../services/membership_plan_service.dart';
import '../widgets/record_card.dart';
import 'person_code.dart';
import '../widgets/selectable_dialog.dart';

const _actions = {
  'SUCCESS': 'Xác nhận đã nhận tiền',
  'FAILED': 'Báo thất bại',
  'CANCELLED': 'Hủy giao dịch',
};

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
    final yes = await showSelectableDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (c) => AlertDialog(
        title: Text(_actions[state]!),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RecordCard(
                  color: Theme.of(c).colorScheme.surfaceContainer,
                  icon: Icons.receipt_long_outlined,
                  title: 'Giao dịch ${personCode(p.id)}',
                  rows: [
                    RecordRow('Nội dung chuyển khoản', transferCode(p.id)),
                    RecordRow('Mã hội viên', personCode(p.memberId)),
                    RecordRow('Gói', p.planName),
                    RecordRow('Số tiền', moneyText(p.cents), strong: true),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kiểm tra đúng khoản tiền trước khi xác nhận. Không thể đổi lại sau khi gửi.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
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
        title: const Text('Duyệt thanh toán'),
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
              'Giao dịch gia hạn của hội viên. Xác nhận sau khi đã kiểm tra tiền về; giao dịch cần đối soát sẽ không tự cộng thời hạn.',
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
                child: ConstrainedBox(
                  key: ValueKey('simulator-${p.id}'),
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SelectionArea(
                    child: RecordCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Giao dịch ${personCode(p.id)}',
                      rows: [
                        RecordRow('Nội dung chuyển khoản', transferCode(p.id)),
                        RecordRow('Mã hội viên', personCode(p.memberId)),
                        RecordRow('Gói', p.planName),
                        RecordRow('Thời hạn', '${p.days} ngày'),
                        RecordRow('Số tiền', moneyText(p.cents), strong: true),
                        RecordRow('Trạng thái', p.statusLabel),
                        RecordRow('Kỳ sử dụng', p.fulfillmentLabel),
                        if (p.reason != null)
                          RecordRow('Lý do đối soát', p.reason!),
                        if (p.start != null && p.end != null)
                          RecordRow(
                            'Thời gian sử dụng',
                            '${showPaidDate(p.start!)} – ${showPaidDate(p.end!)}',
                          ),
                      ],
                      action: p.status != 'PENDING'
                          ? null
                          : Wrap(
                              spacing: 8,
                              children: [
                                for (final state in [
                                  'SUCCESS',
                                  'FAILED',
                                  'CANCELLED',
                                ])
                                  FilledButton(
                                    key: ValueKey('${p.id}-$state'),
                                    onPressed:
                                        busy || loading || pending != null
                                        ? null
                                        : () => confirm(p, state),
                                    child: Text(_actions[state]!),
                                  ),
                              ],
                            ),
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
