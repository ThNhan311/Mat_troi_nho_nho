import 'package:flutter/material.dart';

import '../services/admin_account_service.dart';
import '../services/api_client.dart';
import '../services/initial_activation_service.dart';
import '../services/membership_plan_service.dart';
import 'payment_method.dart';

/// One activation attempt. A retry must reuse the same key and payload, so the
/// server cannot record the same counter payment twice.
class PlanRequest {
  final String key, planName;
  final Map<String, dynamic> payload;
  PlanRequest(MembershipPlan plan, String receipt)
    : key = newActivationKey(),
      planName = plan.name,
      payload = {
        'planId': plan.id,
        'amountCollected': num.parse(decimalPrice(plan.cents)),
        'receiptRef': receipt.trim(),
        'note': null,
      };
}

/// A request that did not clearly succeed; [uncertain] means it may have.
class PlanFailure {
  final PlanRequest request;
  final String message;
  final bool uncertain;
  const PlanFailure(this.request, this.message, this.uncertain);

  PlanFailure.from(this.request, ApiError e)
    : message = e.toString(),
      uncertain = e.outcomeUnknown || e.status == 0 || e.status >= 500;
}

const receiptHelp = 'Số phiếu thu đưa cho khách, dùng để đối chiếu tiền.';

String? receiptError(String? value) =>
    value == null || value.trim().isEmpty || value.runes.length > 100
    ? 'Nhập mã chứng từ, tối đa 100 ký tự.'
    : null;

/// Compact package form for a member who has none yet.
class PlanDialog extends StatefulWidget {
  final ApiClient api;
  final AdminAccount account;

  /// Set when the activation made while adding the account did not finish.
  final PlanFailure? failure;
  const PlanDialog({
    super.key,
    required this.api,
    required this.account,
    this.failure,
  });
  @override
  State<PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<PlanDialog> {
  final _form = GlobalKey<FormState>(), _receipt = TextEditingController();
  List<MembershipPlan>? _plans;
  String? _planId, _error;
  late PlanFailure? _failure = widget.failure;
  bool _busy = false, _checked = false, _transfer = false;
  late final int _epoch = widget.api.sessionEpoch;
  bool get _current => mounted && widget.api.sessionEpoch == _epoch;
  late final _service = InitialActivationService(widget.api);

  /// Fields stay locked while the earlier request may still have gone through.
  bool get _unresolved => _failure?.uncertain ?? false;

  @override
  void initState() {
    super.initState();
    _error = widget.failure?.message;
    _load();
  }

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final plans = await _service.plans();
      if (_current) setState(() => _plans = plans);
    } on ApiError catch (e) {
      if (_current) setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    if (_busy || _unresolved || !_form.currentState!.validate()) return;
    final plan = _plans!.firstWhere((p) => p.id == _planId);
    var receipt = _receipt.text;
    if (_transfer) {
      final reference = await collectByTransfer(context, decimalPrice(plan.cents));
      if (reference == null || !_current) return;
      receipt = reference;
    }
    await _send(PlanRequest(plan, receipt));
  }

  Future<void> _send(PlanRequest request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.create(
        widget.account.profileId,
        request.key,
        request.payload,
      );
      if (mounted) Navigator.pop(context, request.planName);
    } on ApiError catch (e) {
      if (_current) {
        setState(() {
          _failure = PlanFailure.from(request, e);
          _error = _failure!.message;
          _busy = false;
          _checked = false;
        });
      }
    }
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _service.read(widget.account.profileId);
      if (mounted) Navigator.pop(context, saved.planName);
    } on ApiError catch (e) {
      if (_current) {
        setState(() {
          _busy = false;
          _checked = true;
          _error = e.status == 404
              ? 'Máy chủ chưa ghi nhận. Có thể gửi lại cùng yêu cầu.'
              : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text('Gói tập cho ${widget.account.fullName}'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_busy || (plans == null && _error == null))
                    const LinearProgressIndicator(),
                  if (_unresolved)
                    Text(
                      'Chưa rõ gói "${_failure!.request.planName}" đã được ghi '
                      'nhận chưa. Hãy kiểm tra trước khi gửi lại.',
                    )
                  else if (plans != null && plans.isEmpty)
                    const Text('Chưa có gói tập nào. Tạo ở mục Gói tập trước.')
                  else if (plans != null) ...[
                    DropdownButtonFormField<String>(
                      key: const Key('plan-choice'),
                      initialValue: _planId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Gói tập'),
                      items: [
                        for (final p in plans)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(planLabel(p)),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _planId = v),
                      validator: (v) => v == null ? 'Chọn gói.' : null,
                    ),
                    const SizedBox(height: 12),
                    PaymentMethodField(
                      transfer: _transfer,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _transfer = v),
                    ),
                    if (!_transfer) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('plan-receipt'),
                        controller: _receipt,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Mã chứng từ thu tiền tại quầy',
                          helperText: receiptHelp,
                          helperMaxLines: 2,
                        ),
                        validator: receiptError,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bấm "Đã thu tiền, kích hoạt" là xác nhận đã thu đủ tiền '
                        'tại quầy.',
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('plan-close'),
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (_unresolved) ...[
            TextButton(
              key: const Key('plan-check'),
              onPressed: _busy ? null : _check,
              child: const Text('Kiểm tra kết quả'),
            ),
            FilledButton(
              key: const Key('plan-retry'),
              onPressed: _busy || !_checked
                  ? null
                  : () => _send(_failure!.request),
              child: const Text('Gửi lại cùng yêu cầu'),
            ),
          ] else
            FilledButton(
              key: const Key('plan-submit'),
              onPressed: _busy || plans == null || plans.isEmpty
                  ? null
                  : _submit,
              child: Text(
                _transfer ? 'Hiện mã QR' : 'Đã thu tiền, kích hoạt',
              ),
            ),
        ],
      ),
    );
  }
}

String planLabel(MembershipPlan p) =>
    '${p.name} • ${durationText(p.durationDays)} • ${moneyText(p.cents)}';
