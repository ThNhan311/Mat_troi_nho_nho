import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/password_service.dart';
import '../widgets/password_field.dart';

/// Change the password of the signed-in account.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.service});

  final PasswordService service;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _done = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.change(_current.text, _next.text);
      if (!mounted) return;
      setState(() {
        _done = true;
        _current.clear();
        _next.clear();
        _confirm.clear();
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa rõ kết quả. Hãy kiểm tra trước khi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _done
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Đã đổi mật khẩu. Lần đăng nhập sau hãy dùng mật khẩu mới.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Xong'),
                        ),
                      ],
                    )
                  : Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PasswordField(
                            key: const Key('change-current'),
                            controller: _current,
                            enabled: !_busy,
                            label: 'Mật khẩu hiện tại',
                            validator: (v) => v == null || v.isEmpty
                                ? 'Vui lòng nhập mật khẩu hiện tại.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          PasswordField(
                            key: const Key('change-new'),
                            controller: _next,
                            enabled: !_busy,
                            label: 'Mật khẩu mới',
                            validator: (v) =>
                                validateNewPassword(v) ??
                                (v == _current.text
                                    ? 'Phải khác mật khẩu hiện tại.'
                                    : null),
                          ),
                          const SizedBox(height: 18),
                          PasswordField(
                            key: const Key('change-confirm'),
                            controller: _confirm,
                            enabled: !_busy,
                            label: 'Nhập lại mật khẩu mới',
                            validator: (v) =>
                                v != _next.text ? 'Mật khẩu chưa khớp.' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              key: const Key('change-error'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.error),
                            ),
                          ],
                          if (_busy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const Key('change-submit'),
                            onPressed: _busy ? null : _save,
                            child: const Text('Lưu mật khẩu mới'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
