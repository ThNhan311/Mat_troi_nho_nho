import 'package:flutter/material.dart';

class WorkoutPlanEditorPage extends StatefulWidget {
  const WorkoutPlanEditorPage({super.key});

  @override
  State<WorkoutPlanEditorPage> createState() =>
      _WorkoutPlanEditorPageState();
}

class _WorkoutPlanEditorPageState
    extends State<WorkoutPlanEditorPage> {
  final _formKey = GlobalKey<FormState>();

  final _planNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<Map<String, String>> _members = [
    {'id': 'MB001', 'name': 'Nguyễn Minh Anh'},
    {'id': 'MB002', 'name': 'Trần Hoàng Long'},
    {'id': 'MB003', 'name': 'Lê Ngọc Hà'},
  ];

  String? _selectedMemberId;

  final List<Map<String, String>> _exercises = [];

  bool _isSaving = false;

  @override
  void dispose() {
    _planNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _selectedMemberName {
    for (final member in _members) {
      if (member['id'] == _selectedMemberId) {
        return member['name'] ?? '';
      }
    }
    return '';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddExerciseDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Thêm bài tập'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên bài tập',
                        hintText: 'Ví dụ: Squat',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên bài tập.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả bài tập',
                        hintText: 'Hướng dẫn thực hiện bài tập',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
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
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    {
                      'name': nameController.text.trim(),
                      'description':
                      descriptionController.text.trim(),
                    },
                  );
                },
                child: const Text('Thêm'),
              ),
            ],
          );
        },
      );

      if (!mounted || result == null) {
        return;
      }

      setState(() {
        _exercises.add(result);
      });

      _showMessage('Đã thêm bài tập vào giáo án.');
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _removeExercise(int index) async {
    final exercise = _exercises[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa bài tập'),
          content: Text(
            'Bạn có muốn xóa "${exercise['name']}" khỏi giáo án không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Giữ lại'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        _exercises.removeAt(index);
      });

      _showMessage('Đã xóa bài tập.');
    }
  }

  Future<void> _savePlan() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMemberId == null) {
      _showMessage('Vui lòng chọn học viên.');
      return;
    }

    if (_exercises.isEmpty) {
      _showMessage('Vui lòng thêm ít nhất một bài tập.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final workoutPlan = <String, dynamic>{
      'memberId': _selectedMemberId,
      'memberName': _selectedMemberName,
      'name': _planNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'exercises': _exercises
          .map((exercise) => Map<String, String>.from(exercise))
          .toList(),
    };

    try {
      // TODO: Gọi API POST /pt/workout-plans khi backend sẵn sàng.
      // Hiện tại chỉ tạo dữ liệu demo trong bộ nhớ.
      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Tạo giáo án thành công'),
            content: Text(
              'Giáo án: ${workoutPlan['name']}\n'
                  'Học viên: ${workoutPlan['memberName']}\n'
                  'Số bài tập: ${workoutPlan['exercises'].length}\n\n'
                  'Đây là kết quả demo. Giáo án chưa được lưu lên server.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Không thể tạo giáo án: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 32,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giáo án tập luyện',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Tạo giáo án cho học viên'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionCard(
              context,
              title: 'Thông tin giáo án',
              icon: Icons.assignment_outlined,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tên giáo án'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _planNameController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tên giáo án',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên giáo án.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Mô tả'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Mục tiêu hoặc nội dung giáo án',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              context,
              title: 'Học viên',
              icon: Icons.person_outline,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMemberId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chọn học viên',
                  border: OutlineInputBorder(),
                ),
                items: _members.map((member) {
                  return DropdownMenuItem<String>(
                    value: member['id'],
                    child: Text(member['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMemberId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Vui lòng chọn học viên.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              context,
              title: 'Danh sách bài tập',
              icon: Icons.list_alt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_exercises.length} bài tập',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_exercises.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 38,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          const Text('Chưa có bài tập nào'),
                          const SizedBox(height: 4),
                          Text(
                            'Thêm bài tập để hoàn thiện giáo án.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(
                      _exercises.length,
                          (index) => _buildExerciseCard(
                        context,
                        index,
                        _exercises[index],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                      _isSaving ? null : _showAddExerciseDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm bài tập'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _savePlan,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'Đang xử lý...' : 'Tạo giáo án',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dữ liệu hiện là dữ liệu mẫu, chưa được lưu lên backend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Widget child,
      }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
      BuildContext context,
      int index,
      Map<String, String> exercise,
      ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((exercise['description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    exercise['description']!,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xóa bài tập',
            onPressed: _isSaving ? null : () => _removeExercise(index),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}