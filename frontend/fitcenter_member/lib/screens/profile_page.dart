import 'package:flutter/material.dart';

import '../widgets/page_header.dart';
import '../widgets/section_title.dart';
import 'help_page.dart';
import 'about_page.dart';

class ProfilePage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;
  final ValueChanged<String> onShowMessage;
  final VoidCallback onOpenBookingHistory;
  final VoidCallback onOpenMembership;
  final VoidCallback onLogout;
  final VoidCallback? onChangePassword;
  final Widget? avatar;
  final String? profileId;
  final String? name;

  const ProfilePage({
    super.key,
    this.avatar,
    this.profileId,
    this.name,
    required this.isDark,
    required this.onToggleTheme,
    required this.onShowMessage,
    required this.onOpenBookingHistory,
    required this.onOpenMembership,
    required this.onLogout,
    this.onChangePassword,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  Color get iconColor => primaryColor;

  Color get iconBackground => Theme.of(context).colorScheme.primaryContainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                icon: Icons.person_outline,
                title: 'Cá nhân',
                subtitle: 'Quản lý thông tin tài khoản',
              ),
              const SizedBox(height: 24),

              _buildProfileCard(),

              const SizedBox(height: 28),

              const SectionTitle('Tài khoản'),
              const SizedBox(height: 12),

              _buildMenuItem(
                icon: Icons.card_membership_outlined,
                title: 'Gói hội viên',
                subtitle: 'Xem thông tin gói tập hiện tại',
                onTap: widget.onOpenMembership,
              ),

              _buildMenuItem(
                icon: Icons.history,
                title: 'Lịch sử đặt lịch',
                subtitle: 'Xem các buổi tập PT đã đặt',
                onTap: widget.onOpenBookingHistory,
              ),

              if (widget.onChangePassword case final open?)
                _buildMenuItem(
                  icon: Icons.lock_reset,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Cập nhật mật khẩu đăng nhập',
                  onTap: open,
                ),

              const SizedBox(height: 28),

              const SectionTitle('Cài đặt'),
              const SizedBox(height: 12),

              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    secondary: Icon(
                      _isDark ? Icons.dark_mode : Icons.light_mode,
                      color: iconColor,
                    ),
                    title: const Text('Giao diện sáng/tối'),
                    subtitle: Text(
                      _isDark
                          ? 'Đang sử dụng giao diện tối'
                          : 'Đang sử dụng giao diện sáng',
                    ),
                    value: _isDark,
                    onChanged: widget.onToggleTheme,
                    activeThumbColor: primaryColor,
                  ),
                ),
              ),

              _buildMenuItem(
                icon: Icons.help_outline,
                title: 'Trợ giúp',
                subtitle: 'Hỗ trợ sử dụng FitCenter',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const HelpPage()),
                  );
                },
              ),

              _buildMenuItem(
                icon: Icons.info_outline,
                title: 'Về FitCenter',
                subtitle: 'Ứng dụng quản lý hội viên phòng gym',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                  );
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(
                      color: colors.error.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          widget.avatar ??
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, size: 46, color: iconColor),
              ),

          const SizedBox(height: 14),

          Text(
            // Until the server gives a name, the role stands in for it.
            widget.name ?? 'Hội viên',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.name != null) ...[
            const SizedBox(height: 3),
            Text(
              'Hội viên',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ],
          // The first block of the profile id, as the front desk sees it.
          if (widget.profileId case final id? when id.length >= 8) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SelectableText(
                'Mã hội viên: ${id.substring(0, 8).toUpperCase()}',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    showDialog<void>(
      useRootNavigator: false,
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Đăng xuất', style: TextStyle(color: colors.onSurface)),
          content: Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi FitCenter?',
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onLogout();
              },
              child: Text('Đăng xuất', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
  }
}
