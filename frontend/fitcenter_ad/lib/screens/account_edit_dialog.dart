import 'package:flutter/material.dart';

import '../services/account_manage_service.dart';
import '../services/admin_account_service.dart';
import '../services/api_client.dart';
import 'gender.dart';
import 'person_code.dart';
import 'phone_number.dart';

class AccountEditDialog extends StatefulWidget {
  final AccountManageService service;
  final AdminAccount account;
  final String? phone, gender;
  const AccountEditDialog({
    super.key,
    required this.service,
    required this.account,
    this.phone,
    this.gender,
  });
  @override
  State<AccountEditDialog> createState() => _AccountEditDialogState();
}

class _AccountEditDialogState extends State<AccountEditDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account.fullName),
      _email = TextEditingController(text: widget.account.email),
      _phone = TextEditingController(text: widget.phone ?? '');
  late String? _gender = widget.gender;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.update(
        widget.account.userId,
        _name.text,
        _email.text,
        // Older accounts may have none; leaving it empty keeps it that way.
        phone: _phone.text.trim().isNotEmpty
            ? normalizePhone(_phone.text)
            : null,
        gender: _gender,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Sửa tài khoản'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('edit-name'),
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.runes.length > 150
                      ? 'Nhập họ tên, tối đa 150 ký tự.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit-email'),
                  controller: _email,
                  enabled: !_busy && widget.account.activationPending,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    helperText: widget.account.activationPending
                        ? null
                        : 'Tài khoản đã kích hoạt nên không đổi email.',
                  ),
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v.trim())
                      ? 'Email chưa hợp lệ.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit-phone'),
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? (widget.phone == null ? null : phoneError(v))
                      : phoneError(v),
                ),
                const SizedBox(height: 12),
                GenderField(
                  key: const Key('edit-gender'),
                  value: _gender,
                  onChanged: _busy ? null : (v) => _gender = v,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  '${widget.account.role == 'PT' ? 'Mã PT' : 'Mã hội viên'}: '
                  '${personCode(widget.account.profileId)}',
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('edit-save'),
          onPressed: _busy ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
}
