import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/booking_service.dart';
import 'screens/booking_dashboard.dart';
import 'theme/app_theme.dart';

void main() => runApp(const FitCenterApp());

class FitCenterApp extends StatefulWidget {
  final ApiClient? api;
  const FitCenterApp({super.key, this.api});
  @override
  State<FitCenterApp> createState() => _FitCenterAppState();
}

class _FitCenterAppState extends State<FitCenterApp> {
  late final ApiClient api = widget.api ?? ApiClient(expectedRole: 'MEMBER');
  @override
  void dispose() {
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'FitCenter Member',
    theme: AppTheme.lightTheme,
    home: AnimatedBuilder(
      animation: api,
      builder: (context, _) => api.authenticated
          ? BookingDashboard(
              key: ValueKey('dashboard-${api.sessionEpoch}'),
              service: BookingService(api),
            )
          : LoginView(api: api),
    ),
  );
}

class LoginView extends StatefulWidget {
  final ApiClient api;
  const LoginView({super.key, required this.api});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.login(email.text, password.text);
    } on ApiError catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không thể đọc dữ liệu máy chủ. Hãy thử lại.');
      }
    } finally {
      if (mounted) {
        password.clear();
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FitCenter Member • Đăng nhập')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dùng tài khoản MEMBER. Phiên chỉ lưu trong memory; tải lại trang cần đăng nhập lại.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('email'),
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Nhập email hợp lệ.'
                      : null,
                ),
                TextFormField(
                  key: const Key('password'),
                  controller: password,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  onFieldSubmitted: (_) => login(),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Nhập mật khẩu.' : null,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error!, key: const Key('login-error')),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('login'),
                  onPressed: busy ? null : login,
                  child: Text(busy ? 'Đang đăng nhập…' : 'Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
