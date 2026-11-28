import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

import '../services/api_client.dart';
import '../services/pt_activation_service.dart';
import 'pt_activation_page.dart';
import '../services/password_service.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  final ApiClient api;

  const LoginPage({super.key, required this.api});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _busy = false;
  String? _error;
  Future<void> _handleLogin() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(_emailController.text, _passwordController.text);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Không thể đăng nhập. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        _passwordController.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: 20,
              // Keeps the form phone-sized on wide screens.
              horizontal: math.max(
                20,
                (MediaQuery.sizeOf(context).width - 440) / 2,
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(width: 240)),
                  const SizedBox(height: 8),
                  Text(
                    'Bắt đầu hành trình khỏe mạnh của bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Đăng nhập',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          key: const Key('email'),
                          enabled: !_busy,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: colors.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Nhập email của bạn',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập email.';
                            }

                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())) {
                              return 'Email chưa đúng định dạng.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          key: const Key('password'),
                          enabled: !_busy,
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          style: TextStyle(color: colors.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            hintText: 'Nhập mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu.';
                            }

                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('forgot-password'),
                            onPressed: _busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => ForgotPasswordPage(
                                        service: PasswordService(widget.api),
                                        initialEmail: _emailController.text,
                                      ),
                                    ),
                                  ),
                            child: const Text('Quên mật khẩu?'),
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              key: const Key('login-error'),
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        if (_busy) const LinearProgressIndicator(),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            key: const Key('login'),
                            onPressed: _busy ? null : _handleLogin,
                            child: const Text(
                              'ĐĂNG NHẬP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Outlined with an arrow so it clearly reads as a button.
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.primary, width: 1.5),
                          ),
                          onPressed: _busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => PtActivationPage(
                                      service: PtActivationService(widget.api),
                                    ),
                                  ),
                                ),
                          child: const Row(
                            children: [
                              Icon(Icons.how_to_reg_outlined, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Kích hoạt tài khoản PT',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Stays on one line; shrinks a little on narrow phones.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Chưa có tài khoản? Liên hệ phòng tập để được hỗ trợ.',
                            maxLines: 1,
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
