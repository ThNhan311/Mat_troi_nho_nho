import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;
  final ValueChanged<String> onShowMessage;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onShowMessage,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = 'Nguyễn Văn Nam';
  String email = 'nam@example.com';
  String phone = '0123456789';

  final List<Map<String, String>> notifications = [
    {
      'title': 'Chào mừng đến với FitCenter',
      'message':
      'Chào mừng bạn đến với FitCenter! Hãy bắt đầu quản lý lịch làm việc và theo dõi các buổi tập của học viên.',
      'time': 'Hôm nay',
      'type': 'info',
    },
    {
      'title': 'Nhắc nhở lịch làm việc',
      'message':
      'Đừng quên kiểm tra lịch làm việc để chủ động sắp xếp thời gian và chuẩn bị cho các buổi tập.',
      'time': 'Hôm nay',
      'type': 'schedule',
    },
    {
      'title': 'Quản lý giáo án',
      'message':
      'Bạn có thể tạo và quản lý giáo án tập luyện phù hợp với mục tiêu của từng học viên tại mục Giáo án.',
      'time': 'Gần đây',
      'type': 'workout',
    },
  ];

  final Set<int> readNotifications = {};

  int get unreadCount => notifications.length - readNotifications.length;

  void _toggleTheme() {
    widget.onToggleTheme(!widget.isDark);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Huấn luyện viên cá nhân',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa thông tin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Thông tin liên hệ'),
          _buildInfoItem(
            icon: Icons.email_outlined,
            title: 'Email',
            value: email,
          ),
          _buildInfoItem(
            icon: Icons.phone_outlined,
            title: 'Số điện thoại',
            value: phone,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Cài đặt'),
          _buildMenuItem(
            icon: widget.isDark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            title: 'Giao diện tối',
            subtitle: widget.isDark
                ? 'Đang bật chế độ tối'
                : 'Đang bật chế độ sáng',
            trailing: Switch(
              value: widget.isDark,
              onChanged: (value) => widget.onToggleTheme(value),
            ),
            onTap: _toggleTheme,
          ),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Thông báo',
            subtitle: unreadCount > 0
                ? '$unreadCount thông báo chưa đọc'
                : 'Xem thông báo của FitCenter',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unreadCount > 0)
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colors.primary,
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _showNotifications,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Hỗ trợ'),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Trợ giúp',
            subtitle: 'Hướng dẫn sử dụng FitCenter',
            onTap: _showHelpDialog,
          ),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: 'Giới thiệu',
            subtitle: 'Thông tin về ứng dụng FitCenter',
            onTap: _showAboutDialog,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Icon(icon, color: colors.primary),
          title: Text(title),
          subtitle: Text(value),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: colors.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  void _showNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NotificationsPage(
          notifications: notifications,
          readNotifications: readNotifications,
          onRead: (index) {
            if (!mounted) return;
            setState(() {
              readNotifications.add(index);
            });
          },
          onReadAll: () {
            if (!mounted) return;
            setState(() {
              readNotifications.addAll(
                List.generate(notifications.length, (index) => index),
              );
            });
          },
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: fullName);
    final emailController = TextEditingController(text: email);
    final phoneController = TextEditingController(text: phone);

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Chỉnh sửa thông tin cá nhân'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newEmail = emailController.text.trim();
                final newPhone = phoneController.text.trim();

                if (newName.isEmpty ||
                    newEmail.isEmpty ||
                    newPhone.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền đầy đủ thông tin.'),
                    ),
                  );
                  return;
                }

                if (!newEmail.contains('@') || !newEmail.contains('.')) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Email chưa hợp lệ.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {
                  'name': newName,
                  'email': newEmail,
                  'phone': newPhone,
                });
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      );

      if (!mounted || result == null) return;

      setState(() {
        fullName = result['name']!;
        email = result['email']!;
        phone = result['phone']!;
      });

      widget.onShowMessage('Đã cập nhật thông tin cá nhân.');
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 8),
            Expanded(child: Text('Trợ giúp')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chào mừng bạn đến với FitCenter!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'FitCenter hỗ trợ huấn luyện viên quản lý lịch làm việc, '
                    'theo dõi buổi tập và xây dựng giáo án cho học viên.',
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                Icons.calendar_month_outlined,
                'Lịch làm',
                'Xem và quản lý các khung giờ làm việc của bạn.',
                dialogContext,
              ),
              _buildHelpItem(
                Icons.event_note_outlined,
                'Buổi tập',
                'Theo dõi lịch tập, cập nhật trạng thái hoàn thành hoặc hủy buổi tập.',
                dialogContext,
              ),
              _buildHelpItem(
                Icons.fitness_center_outlined,
                'Giáo án',
                'Tạo và quản lý kế hoạch tập luyện phù hợp với học viên.',
                dialogContext,
              ),
              _buildHelpItem(
                Icons.person_outline,
                'Cá nhân',
                'Cập nhật thông tin, thay đổi giao diện và xem thông báo.',
                dialogContext,
              ),
              const SizedBox(height: 8),
              Text(
                'Lưu ý: Một số dữ liệu trong phiên bản demo được lưu tạm thời '
                    'và có thể chưa được đồng bộ với máy chủ.',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(
      IconData icon,
      String title,
      String description,
      BuildContext dialogContext,
      ) {
    final colors = Theme.of(dialogContext).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Giới thiệu FitCenter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.fitness_center,
                    size: 36,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FitCenter',
                  style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ứng dụng hỗ trợ huấn luyện viên quản lý lịch làm việc, '
                      'theo dõi các buổi tập và tổ chức giáo án cho học viên.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _buildAboutFeature(
                  Icons.calendar_month_outlined,
                  'Quản lý lịch làm việc',
                  dialogContext,
                ),
                _buildAboutFeature(
                  Icons.event_available_outlined,
                  'Theo dõi trạng thái buổi tập',
                  dialogContext,
                ),
                _buildAboutFeature(
                  Icons.assignment_outlined,
                  'Tổ chức giáo án tập luyện',
                  dialogContext,
                ),
                _buildAboutFeature(
                  Icons.notifications_outlined,
                  'Xem thông báo trong ứng dụng',
                  dialogContext,
                ),
                const SizedBox(height: 12),
                const Text(
                  'FitCenter hướng đến việc giúp huấn luyện viên làm việc '
                      'khoa học, thuận tiện và hiệu quả hơn.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Phiên bản 1.0.0',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutFeature(
      IconData icon,
      String text,
      BuildContext dialogContext,
      ) {
    final colors = Theme.of(dialogContext).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi FitCenter không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onLogout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  final List<Map<String, String>> notifications;
  final Set<int> readNotifications;
  final ValueChanged<int> onRead;
  final VoidCallback onReadAll;

  const _NotificationsPage({
    required this.notifications,
    required this.readNotifications,
    required this.onRead,
    required this.onReadAll,
  });

  IconData _notificationIcon(String? type) {
    switch (type) {
      case 'schedule':
        return Icons.calendar_month_outlined;
      case 'workout':
        return Icons.fitness_center_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unreadCount = notifications.length - readNotifications.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: onReadAll,
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text('Bạn chưa có thông báo nào.'),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final isRead = readNotifications.contains(index);

          return Material(
            color: isRead
                ? colors.surface
                : colors.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: colors.surface,
                child: Icon(
                  _notificationIcon(notification['type']),
                  color: colors.primary,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      notification['title']!,
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['message']!),
                    const SizedBox(height: 8),
                    Text(
                      notification['time']!,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                if (!isRead) {
                  onRead(index);
                }
              },
            ),
          );
        },
      ),
    );
  }
}