
import 'package:flutter/material.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Gói 1 tháng',
      'price': 500000,
      'duration': 1,
      'active': true,
    },
    {
      'name': 'Gói 3 tháng',
      'price': 1350000,
      'duration': 3,
      'active': true,
    },
    {
      'name': 'Gói 6 tháng',
      'price': 2400000,
      'duration': 6,
      'active': true,
    },
    {
      'name': 'Gói 12 tháng',
      'price': 4200000,
      'duration': 12,
      'active': false,
    },
  ];

  String _formatPrice(int price) {
    final digits = price.toString();
    final result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      result.write(digits[i]);

      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        result.write('.');
      }
    }

    return '${result.toString()} đ';
  }

  Future<void> _showPlanDialog({int? index}) async {
    final isEditing = index != null;
    final plan = isEditing ? _plans[index] : null;

    String name = plan?['name'] ?? '';
    String priceText = plan == null ? '' : plan['price'].toString();
    String durationText =
    plan == null ? '' : plan['duration'].toString();

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Sửa gói tập' : 'Thêm gói tập'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    onChanged: (value) => name = value,
                    decoration: const InputDecoration(
                      labelText: 'Tên gói tập',
                      hintText: 'Ví dụ: Gói 1 tháng',
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.isEmpty) {
                        return 'Vui lòng nhập tên gói';
                      }

                      final nameExists = _plans.asMap().entries.any((entry) {
                        if (isEditing && entry.key == index) {
                          return false;
                        }

                        return (entry.value['name'] as String).toLowerCase() ==
                            name.toLowerCase();
                      });

                      if (nameExists) {
                        return 'Tên gói này đã tồn tại';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: priceText,
                    onChanged: (value) => priceText = value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giá (VNĐ)',
                    ),
                    validator: (value) {
                      final price = int.tryParse(value ?? '');
                      if (price == null || price <= 0) {
                        return 'Nhập mức giá hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: durationText,
                    onChanged: (value) => durationText = value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời hạn (tháng)',
                    ),
                    validator: (value) {
                      final duration = int.tryParse(value ?? '');
                      if (duration == null || duration <= 0) {
                        return 'Nhập số tháng hợp lệ';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(dialogContext, {
                  'name': name.trim(),
                  'price': int.parse(priceText.trim()),
                  'duration': int.parse(durationText.trim()),
                  'active': plan?['active'] ?? true,
                });
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      if (isEditing) {
        _plans[index] = result;
      } else {
        _plans.add(result);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Đã cập nhật gói tập' : 'Đã thêm gói tập'),
      ),
    );
  }

  Future<void> _deletePlan(int index) async {
    final planName = _plans[index]['name'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa gói tập'),
        content: Text(
          'Bạn có chắc chắn muốn xóa gói "$planName" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _plans.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xóa gói "$planName"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý gói tập',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlanDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm gói'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text(
              'MEMBERSHIP PLANS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các gói hội viên',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý giá, thời hạn và trạng thái các gói tập.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ...List.generate(_plans.length, (index) {
              final plan = _plans[index];
              final isActive = plan['active'] as bool;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.dividerColor.withOpacity(0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.card_membership_outlined,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              plan['name'] as String,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sửa gói',
                            onPressed: () => _showPlanDialog(index: index),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Xóa gói',
                            onPressed: () => _deletePlan(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _formatPrice(plan['price'] as int),
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Thời hạn: ${plan['duration']} tháng'),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  isActive
                                      ? Icons.check_circle_outline
                                      : Icons.pause_circle_outline,
                                  size: 19,
                                  color: isActive
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    isActive ? 'Đang hoạt động' : 'Đã ngừng',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (value) {
                              setState(() {
                                plan['active'] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
