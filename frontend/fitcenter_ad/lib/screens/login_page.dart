import 'package:flutter/material.dart';

import '../services/api_client.dart';

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
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.fitness_center, size: 72, color: colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'FITCENTER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản trị FitCenter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Đăng nhập',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập bằng tài khoản Admin.',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
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
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

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
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('login'),
                      onPressed: _busy ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ĐĂNG NHẬP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Chưa có tài khoản? Liên hệ phòng tập để được hỗ trợ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),

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
