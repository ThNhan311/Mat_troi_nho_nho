import '../services/booking_policy_service.dart';

import 'package:flutter/material.dart';

import 'booking_policy_page.dart';
import 'membership_page.dart';
import '../services/membership_plan_service.dart';

class AdminHomePage extends StatelessWidget {
  final BookingPolicyService service;
  final MembershipPlanService plans;
  final VoidCallback onLogout;
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;

  const AdminHomePage({
    super.key,
    required this.service,
    required this.plans,
    required this.onLogout,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FITCENTER',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: isDark ? 'Giao diện sáng' : 'Giao diện tối',
            onPressed: () => onToggleTheme(!isDark),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: colors.primary.withOpacity(0.15),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADMIN PANEL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Xin chào, Admin',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Quản lý hoạt động phòng gym của bạn.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 28),

              _SectionTitle(title: 'TỔNG QUAN', trailing: 'Chưa khả dụng'),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.28,
                children: const [
                  _SummaryCard(
                    icon: Icons.people_outline,
                    title: 'Hội viên',
                    value: '—',
                  ),
                  _SummaryCard(
                    icon: Icons.fitness_center,
                    title: 'Huấn luyện viên',
                    value: '—',
                  ),
                  _SummaryCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Lịch đặt',
                    value: '—',
                  ),
                  _SummaryCard(
                    icon: Icons.payments_outlined,
                    title: 'Thanh toán',
                    value: '—',
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const _SectionTitle(title: 'QUẢN LÝ HỆ THỐNG'),
              const SizedBox(height: 14),

              _AdminMenuCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Hội viên & PT',
                subtitle: 'Quản lý tài khoản và trạng thái hoạt động',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const _ComingSoonPage(
                        title: 'Chưa khả dụng',
                        description: 'Chức năng chưa khả dụng.',
                      ),
                    ),
                  );
                },
              ),

              _AdminMenuCard(
                icon: Icons.card_membership_outlined,
                title: 'Gói tập',
                subtitle: 'Xem gói đang hoạt động và thêm gói tập',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MembershipPage(service: plans, onLogout: onLogout),
                    ),
                  );
                },
              ),

              _AdminMenuCard(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Kích hoạt Gói hội viên',
                subtitle: 'Đăng ký hội viên và kích hoạt gói tập lần đầu',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const _ComingSoonPage(
                        title: 'Chưa khả dụng',
                        description: 'Chức năng chưa khả dụng.',
                      ),
                    ),
                  );
                },
              ),

              _AdminMenuCard(
                icon: Icons.event_available_outlined,
                title: 'Chính sách đặt lịch',
                subtitle: 'Thiết lập quy định booking',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BookingPolicyPage(
                        service: service,
                        onLogout: onLogout,
                      ),
                    ),
                  );
                },
              ),
              _AdminMenuCard(
                icon: Icons.receipt_long_outlined,
                title: 'Lịch sử hoạt động',
                subtitle: 'Theo dõi booking, thanh toán và điểm danh',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const _ComingSoonPage(
                        title: 'Chưa khả dụng',
                        description: 'Chức năng chưa khả dụng.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  final String title;
  final String description;

  const _ComingSoonPage({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(description, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
