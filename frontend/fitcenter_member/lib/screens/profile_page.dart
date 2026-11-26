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
  final Widget? avatar;

  const ProfilePage({
    super.key,
    this.avatar,
    required this.isDark,
    required this.onToggleTheme,
    required this.onShowMessage,
    required this.onOpenBookingHistory,
    required this.onOpenMembership,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = 'Hội viên';

  static const Color _lightIconColor = Color(0xFF737B87);
  static const Color _lightIconBackground = Color(0xFFF0F1F3);
  static const Color _lightBorderColor = Color(0xFFE5E7EB);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  Color get iconColor => _isDark ? primaryColor : _lightIconColor;

  Color get iconBackground =>
      _isDark ? primaryColor.withValues(alpha: 0.12) : _lightIconBackground;

  Color get _cardBorderColor => _isDark
      ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.25)
      : _lightBorderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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

              const SizedBox(height: 28),

              const SectionTitle('Cài đặt'),
              const SizedBox(height: 12),

              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorderColor),
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
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
        border: Border.all(color: _cardBorderColor),
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
            fullName,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorderColor),
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
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }
}
