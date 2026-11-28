import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

import '../services/api_client.dart';
import '../services/member_activation_service.dart';

class MemberActivationPage extends StatefulWidget {
  final MemberActivationService service;
  const MemberActivationPage({super.key, required this.service});
  @override
  State<MemberActivationPage> createState() => _MemberActivationPageState();
}

class _MemberActivationPageState extends State<MemberActivationPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _otp = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  int _phase = 0;
  bool _busy = false, _unknown = false;
  bool _hidePassword = true, _hideConfirm = true;
  String? _error, _grant;
  late final int _epoch = widget.service.session.sessionEpoch;
  bool get _current => mounted && widget.service.session.sessionEpoch == _epoch;
  @override
  void initState() {
    super.initState();
    widget.service.session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!_current && mounted) {
      _grant = null;
      _otp.clear();
      _password.clear();
      _confirm.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.service.session.removeListener(_sessionChanged);
    widget.service.dispose();
    _grant = null;
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _action({bool resend = false}) async {
    if (_busy ||
        _unknown ||
        !_current ||
        (!resend && !_form.currentState!.validate()))
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_phase == 0 || resend) {
        await widget.service.request(_email.text);
        if (_current)
          setState(() {
            _phase = 1;
            _otp.clear();
            _grant = null;
          });
      } else if (_phase == 1) {
        final grant = await widget.service.verify(_email.text, _otp.text);
        if (_current)
          setState(() {
            _grant = grant;
            _otp.clear();
            _phase = 2;
          });
      } else if (_phase == 2) {
        await widget.service.password(_grant!, _password.text);
        if (_current)
          setState(() {
            _grant = null;
            _password.clear();
            _confirm.clear();
            _phase = 3;
          });
      }
    } on ApiError catch (e) {
      if (_current)
        setState(() {
          _error = e.code == 'ERR_ACTIVATION_NOT_READY'
              ? 'Kích hoạt Member chưa sẵn sàng. Vui lòng liên hệ phòng tập. [${e.code}]'
              : e.toString();
          _unknown = e.outcomeUnknown;
        });
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kích hoạt tài khoản Member')),
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(width: 240)),
                    const SizedBox(height: 24),
                    if (_phase == 0) ...[
                      const Text(
                        'Nhập email Member đã được phòng tập tạo để nhận mã kích hoạt.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const Key('activation-email'),
                        controller: _email,
                        enabled: !_busy && !_unknown,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) =>
                            v == null ||
                                v.length > 255 ||
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(v.trim())
                            ? 'Email chưa hợp lệ.'
                            : null,
                      ),
                    ],
                    if (_phase == 1) ...[
                      const Text(
                        'Nếu tài khoản đủ điều kiện, mã đã được gửi qua email. Mã có hiệu lực 5 phút.',
                      ),
                      const SizedBox(height: 18),
                      // Resend sits inside the code field, at its right edge.
                      TextFormField(
                        key: const Key('activation-otp'),
                        controller: _otp,
                        enabled: !_busy && !_unknown,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Mã OTP',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: TextButton(
                              onPressed: _busy || _unknown
                                  ? null
                                  : () => _action(resend: true),
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
                    if (_phase == 2) ...[
                      const Text(
                        'Đã xác thực email. Đặt mật khẩu để hoàn tất kích hoạt.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const Key('activation-password'),
                        controller: _password,
                        enabled: !_busy && !_unknown,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: () => setState(
                              () => _hidePassword = !_hidePassword,
                            ),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null ||
                                v.trim().isEmpty ||
                                v.runes.length < 8 ||
                                utf8.encode(v).length > 72
                            ? 'Ít nhất 8 ký tự, tối đa 72 byte UTF-8.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const Key('activation-confirm'),
                        controller: _confirm,
                        enabled: !_busy && !_unknown,
                        obscureText: _hideConfirm,
                        decoration: InputDecoration(
                          labelText: 'Nhập lại mật khẩu',
                          suffixIcon: IconButton(
                            tooltip: _hideConfirm
                                ? 'Hiện mật khẩu nhập lại'
                                : 'Ẩn mật khẩu nhập lại',
                            onPressed: () => setState(
                              () => _hideConfirm = !_hideConfirm,
                            ),
                            icon: Icon(
                              _hideConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v != _password.text ? 'Mật khẩu chưa khớp.' : null,
                      ),
                    ],
                    if (_phase == 3)
                      const Text(
                        'Đã kích hoạt tài khoản. Bạn có thể đăng nhập bằng email và mật khẩu vừa đặt.',
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: color.error),
                        ),
                      ),
                    if (_unknown)
                      const Text(
                        'Kết quả chưa rõ. Không gửi lại thao tác này; quay về đăng nhập để kiểm tra.',
                      ),
                    if (_busy) const LinearProgressIndicator(),
                    // The verify button moves up, right under the code row.
                    SizedBox(height: _phase == 1 ? 12 : 24),
                    if (_phase < 3)
                      ElevatedButton(
                        onPressed: _busy || _unknown ? null : _action,
                        child: Text(
                          _phase == 0
                              ? 'Nhận OTP'
                              : _phase == 1
                              ? 'Xác thực OTP'
                              : 'Hoàn tất kích hoạt',
                        ),
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
