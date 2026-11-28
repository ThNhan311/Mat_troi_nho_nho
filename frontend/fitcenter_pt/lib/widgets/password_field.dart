import 'dart:convert';

import 'package:flutter/material.dart';

/// The same limits the server applies.
String? validateNewPassword(String? value) {
  if (value == null ||
      value.trim().isEmpty ||
      value.runes.length < 8 ||
      utf8.encode(value).length > 72) {
    return 'Ít nhất 8 ký tự.';
  }
  return null;
}

/// A password box with its own show / hide button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
