import 'package:flutter/material.dart';

/// What the server stores, and what people read.
const genderLabels = {'MALE': 'Nam', 'FEMALE': 'Nữ'};

/// An optional Nam / Nữ choice.
class GenderField extends StatelessWidget {
  const GenderField({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: genderLabels.containsKey(value) ? value : null,
    isExpanded: true,
    hint: const Text('Chưa chọn'),
    decoration: const InputDecoration(
      labelText: 'Giới tính',
      prefixIcon: Icon(Icons.wc),
    ),
    items: [
      for (final entry in genderLabels.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: onChanged,
  );
}
