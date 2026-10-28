import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'availability_page.dart';
import 'home_screen.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;

  const HomePage({
    super.key,
    required this.onLogout,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  final List<Map<String, String>> sessions = [
    {
      'member': 'Nguyễn Minh Anh',
      'date': 'Hôm nay',
      'time': '08:00 - 09:00',
      'status': 'CONFIRMED',
      'note': '',
    },
    {
      'member': 'Trần Hoàng Phúc',
      'date': 'Hôm nay',
      'time': '14:00 - 15:00',
      'status': 'CONFIRMED',
      'note': '',
    },
  ];

  final List<Map<String, String>> workoutPlans = [
    {
      'name': 'Giáo án thể lực cơ bản',
      'member': 'Nguyễn Minh Anh',
    },
  ];

  // ============================================================
  // COMMON
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _selectPage(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool currentIsDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeScreen(
            onOpenSchedule: () => _selectPage(1),
            onShowMessage: _showMessage,
          ),
          const AvailabilityPage(),
          _buildSessionsPage(),
          _buildWorkoutPage(),
          ProfilePage(
            isDark: currentIsDark,
            onToggleTheme: widget.onToggleTheme,
            onShowMessage: _showMessage,
            onLogout: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch làm',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Buổi tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Giáo án',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON PAGE
  // ============================================================

  Widget _buildPage({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    Widget? floatingActionButton,
  }) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: AppColors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
        top: 8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // BUỔI TẬP
  // ============================================================

  Widget _buildSessionsPage() {
    return _buildPage(
      title: 'Buổi tập đã xác nhận',
      subtitle:
      'Theo dõi và cập nhật trạng thái buổi tập với học viên.',
      icon: Icons.event_note,
      children: [
        _buildSectionTitle('Danh sách buổi tập'),

        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('Chưa có buổi tập nào.'),
            ),
          )
        else
          ...sessions.map(_buildSessionCard),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSessionCard(
      Map<String, String> session,
      ) {
    final String status = session['status'] ?? '';

    final bool completed = status == 'COMPLETED';
    final bool cancelled = status == 'CANCELLED';
    final bool confirmed = status == 'CONFIRMED';

    final String statusText;

    if (completed) {
      statusText = 'Đã hoàn thành';
    } else if (cancelled) {
      statusText = 'Đã hủy';
    } else {
      statusText = 'Đã xác nhận';
    }

    final Color statusColor;

    if (completed) {
      statusColor = AppColors.green;
    } else if (cancelled) {
      statusColor = Colors.redAccent;
    } else {
      statusColor = Theme.of(context).colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(
                session['member'] ?? 'Không rõ học viên',
              ),
              subtitle: Text(
                '${session['date'] ?? ''} • '
                    '${session['time'] ?? ''}',
              ),
            ),

            const SizedBox(height: 4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (confirmed) ...[
                  TextButton(
                    onPressed: () {
                      _showCancelSessionDialog(session);
                    },
                    child: const Text('Hủy buổi tập'),
                  ),

                  const SizedBox(width: 4),

                  FilledButton(
                    onPressed: () {
                      _completeSession(session);
                    },
                    child: const Text('Hoàn thành'),
                  ),
                ],
              ],
            ),

            if ((session['note'] ?? '').isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lý do hủy: ${session['note']}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _completeSession(
      Map<String, String> session,
      ) {
    if (session['status'] != 'CONFIRMED') {
      _showMessage(
        'Chỉ buổi tập đã xác nhận mới được hoàn thành.',
      );
      return;
    }

    setState(() {
      session['status'] = 'COMPLETED';
    });

    _showMessage(
      'Đã đánh dấu buổi tập hoàn thành.',
    );
  }

  // ============================================================
  // HỦY BUỔI TẬP
  // ============================================================

  Future<void> _showCancelSessionDialog(
      Map<String, String> session,
      ) async {
    final String? reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const _CancelSessionDialog();
      },
    );

    if (!mounted || reason == null) {
      return;
    }

    // Không setState ngay trong lúc route/dialog
    // vừa kết thúc transition.
    //
    // Chờ frame hiện tại hoàn tất rồi mới rebuild
    // HomePage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        session['status'] = 'CANCELLED';
        session['note'] = reason;
      });

      _showMessage(
        'Đã hủy buổi tập.',
      );
    });
  }

  // ============================================================
  // GIÁO ÁN
  // ============================================================

  Widget _buildWorkoutPage() {
    return _buildPage(
      title: 'Giáo án',
      subtitle:
      'Tạo và quản lý giáo án tập luyện cho học viên.',
      icon: Icons.fitness_center,
      children: [
        _buildSectionTitle('Giáo án hiện có'),

        if (workoutPlans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('Chưa có giáo án nào.'),
            ),
          )
        else
          ...workoutPlans.map(
                (plan) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(
                    Icons.assignment_outlined,
                  ),
                  title: Text(
                    plan['name'] ?? 'Giáo án',
                  ),
                  subtitle: Text(
                    'Học viên: '
                        '${plan['member'] ?? 'Chưa xác định'}',
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _showCreatePlanDialog,
            icon: const Icon(Icons.add),
            label: const Text('Tạo giáo án'),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _showCreatePlanDialog() async {
    final Map<String, String>? result =
    await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const _CreateWorkoutPlanDialog();
      },
    );

    if (!mounted || result == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        workoutPlans.add(result);
      });

      _showMessage(
        'Đã tạo giáo án.',
      );
    });
  }
}

// ============================================================================
// CANCEL SESSION DIALOG
// ============================================================================

class _CancelSessionDialog extends StatefulWidget {
  const _CancelSessionDialog();

  @override
  State<_CancelSessionDialog> createState() =>
      _CancelSessionDialogState();
}

class _CancelSessionDialogState
    extends State<_CancelSessionDialog> {
  late final TextEditingController reasonController;

  @override
  void initState() {
    super.initState();

    reasonController = TextEditingController();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _confirm() {
    final String reason =
    reasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng nhập lý do hủy buổi tập.',
            ),
          ),
        );

      return;
    }

    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hủy buổi tập'),

      content: TextField(
        controller: reasonController,
        minLines: 2,
        maxLines: 4,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Lý do hủy',
          hintText: 'Nhập lý do hủy buổi tập',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Quay lại'),
        ),

        FilledButton(
          onPressed: _confirm,
          child: const Text('Xác nhận hủy'),
        ),
      ],
    );
  }
}

// ============================================================================
// CREATE WORKOUT PLAN DIALOG
// ============================================================================

class _CreateWorkoutPlanDialog
    extends StatefulWidget {
  const _CreateWorkoutPlanDialog();

  @override
  State<_CreateWorkoutPlanDialog> createState() =>
      _CreateWorkoutPlanDialogState();
}

class _CreateWorkoutPlanDialogState
    extends State<_CreateWorkoutPlanDialog> {
  late final TextEditingController nameController;
  late final TextEditingController memberController;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController();
    memberController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    memberController.dispose();

    super.dispose();
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _create() {
    final String name =
    nameController.text.trim();

    final String member =
    memberController.text.trim();

    if (name.isEmpty || member.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng nhập đầy đủ thông tin.',
            ),
          ),
        );

      return;
    }

    Navigator.of(context).pop(
      {
        'name': name,
        'member': member,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo giáo án'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên giáo án',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: memberController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Tên học viên',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Hủy'),
        ),

        FilledButton(
          onPressed: _create,
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}