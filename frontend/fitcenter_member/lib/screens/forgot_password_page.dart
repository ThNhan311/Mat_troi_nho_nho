import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/password_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/password_field.dart';

/// Forgot password: email, then the emailed code, then a new password.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.service,
    this.initialEmail = '',
  });

  final PasswordService service;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// 0 email, 1 code, 2 new password, 3 done.
  int _step = 0;
  bool _busy = false;
  String? _error, _notice, _token;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Có lỗi xảy ra. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (!_form.currentState!.validate()) return;
    _run(() async {
      if (_step == 0) {
        await widget.service.requestCode(_email.text);
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        final token = await widget.service.verify(_email.text, _otp.text);
        if (mounted) {
          setState(() {
            _token = token;
            _otp.clear();
            _step = 2;
          });
        }
      } else {
        await widget.service.reset(_token!, _password.text);
        if (mounted) {
          setState(() {
            _token = null;
            _password.clear();
            _confirm.clear();
            _step = 3;
          });
        }
      }
    });
  }

  void _resend() => _run(() async {
    await widget.service.requestCode(_email.text);
    if (mounted) {
      setState(() {
        _otp.clear();
        _notice = 'Đã gửi lại. Hãy dùng mã mới nhất trong email.';
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Align(
            alignment: Alignment.bottomLeft,
            heightFactor: 1,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text('Về đăng nhập'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(width: 220)),
                    const SizedBox(height: 24),
                    Text(
                      const [
                        'Nhập email tài khoản để nhận mã đặt lại mật khẩu.',
                        'Nếu email này có tài khoản, mã 6 số đã được gửi. Mã có hiệu lực 5 phút.',
                        'Đã xác thực email. Hãy đặt mật khẩu mới.',
                        'Đã đổi mật khẩu. Bạn có thể đăng nhập bằng mật khẩu mới.',
                      ][_step],
                      textAlign: TextAlign.center,
                    ),
                    if (_step == 0) ...[
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const Key('reset-email'),
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) =>
                            v == null ||
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(v.trim())
                            ? 'Email chưa hợp lệ.'
                            : null,
                      ),
                    ],
                    if (_step == 1) ...[
                      const SizedBox(height: 18),
                      // Resend sits inside the code field, as on activation.
                      TextFormField(
                        key: const Key('reset-otp'),
                        controller: _otp,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Mã OTP',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: TextButton(
                              onPressed: _busy ? null : _resend,
                              child: const Text('Gửi lại OTP'),
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null || !RegExp(r'^[0-9]{6}$').hasMatch(v)
                            ? 'Nhập mã gồm 6 chữ số.'
                            : null,
                      ),
                    ],
                    if (_step == 2) ...[
                      const SizedBox(height: 18),
                      PasswordField(
                        key: const Key('reset-password'),
                        controller: _password,
                        enabled: !_busy,
                        label: 'Mật khẩu mới',
                        validator: validateNewPassword,
                      ),
                      const SizedBox(height: 18),
                      PasswordField(
                        key: const Key('reset-confirm'),
                        controller: _confirm,
                        enabled: !_busy,
                        label: 'Nhập lại mật khẩu mới',
                        validator: (v) =>
                            v != _password.text ? 'Mật khẩu chưa khớp.' : null,
                      ),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 10),
                      Text(_notice!, textAlign: TextAlign.center),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        key: const Key('reset-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                    if (_step < 3) ...[
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('reset-submit'),
                        onPressed: _busy ? null : _next,
                        child: Text(
                          const [
                            'Nhận mã OTP',
                            'Xác thực OTP',
                            'Đặt mật khẩu mới',
                          ][_step],
                        ),
                      ),
                    ],
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
