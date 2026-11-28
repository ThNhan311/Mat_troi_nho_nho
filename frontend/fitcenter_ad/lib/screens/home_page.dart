import 'face_enroll_dialog.dart';
import 'open_kiosk_button.dart';
import 'face_enrollment_page.dart';
import '../services/face_enrollment_service.dart';
import 'payment_simulator_page.dart';
import 'report_pages.dart';
import '../services/report_service.dart';
import '../services/kiosk_desk_service.dart';
import '../services/payment_simulator_service.dart';
import '../services/booking_policy_service.dart';

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

import 'booking_policy_page.dart';
import 'desktop_shell.dart';
import 'membership_page.dart';
import 'account_page.dart';
import '../services/admin_account_service.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= adminDesktopBreakpoint
          ? AdminDesktopShell(
              sections: _sections(),
              shortcut: faceKioskEnabled
                  ? OpenKioskButton(service: KioskDeskService(service.api))
                  : null,
              onLogout: onLogout,
              onToggleTheme: onToggleTheme,
            )
          : _compact(context),
    );
  }

  List<AdminSection> _sections() => [
    AdminSection(
      icon: Icons.calendar_month_outlined,
      title: 'Lịch tập',
      maxWidth: 1280,
      builder: (_) => SchedulePage(service: ReportService(service.api)),
    ),
    AdminSection(
      group: 'Quản lý',
      icon: Icons.manage_accounts_outlined,
      title: 'Hội viên & PT',
      maxWidth: 1280,
      builder: (_) => AccountsPage(
        service: AdminAccountService(service.api),
        onLogout: onLogout,
        kiosk: _kiosk,
      ),
    ),
    AdminSection(
      group: 'Quản lý',
      icon: Icons.card_membership_outlined,
      title: 'Gói tập',
      maxWidth: 1280,
      builder: (_) => MembershipPage(service: plans, onLogout: onLogout),
    ),
    AdminSection(
      group: 'Vận hành',
      icon: Icons.event_available_outlined,
      title: 'Chính sách đặt lịch',
      builder: (_) => BookingPolicyPage(service: service, onLogout: onLogout),
    ),
    AdminSection(
      group: 'Vận hành',
      icon: Icons.payments_outlined,
      title: 'Duyệt thanh toán',
      maxWidth: 1000,
      builder: (_) =>
          PaymentSimulatorPage(service: PaymentSimulatorService(service.api)),
    ),
    // With a camera screen, faces are handled in the account list.
    if (!faceKioskEnabled)
      AdminSection(
        group: 'Vận hành',
        icon: Icons.face_outlined,
        title: 'Đăng ký khuôn mặt',
        builder: (_) => _facePage(),
      ),
  ];

  KioskDeskService? get _kiosk =>
      faceKioskEnabled ? KioskDeskService(service.api) : null;

  Widget _facePage() =>
      FaceEnrollmentPage(service: FaceEnrollmentService(service.api));

  Widget _compact(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(width: 120),
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

              if (faceKioskEnabled) ...[
                SizedBox(
                  width: double.infinity,
                  child: OpenKioskButton(
                    service: KioskDeskService(service.api),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const _SectionTitle(title: 'QUẢN LÝ HỆ THỐNG'),
              const SizedBox(height: 14),

              _AdminMenuCard(
                icon: Icons.calendar_month_outlined,
                title: 'Lịch tập',
                subtitle: 'Lịch của tất cả PT và hội viên',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SchedulePage(service: ReportService(service.api)),
                  ),
                ),
              ),
              _AdminMenuCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Hội viên & PT',
                subtitle: 'Quản lý tài khoản và trạng thái hoạt động',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AccountsPage(
                        service: AdminAccountService(service.api),
                        onLogout: onLogout,
                        kiosk: _kiosk,
                      ),
                    ),
                  );
                },
              ),

              if (!faceKioskEnabled)
                _AdminMenuCard(
                  icon: Icons.face_outlined,
                  title: 'Đăng ký khuôn mặt',
                  subtitle: 'Xác minh hội viên, consent và quản lý hồ sơ',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => _facePage())),
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
                icon: Icons.payments_outlined,
                title: 'Duyệt thanh toán',
                subtitle:
                    'Xác nhận thanh toán gia hạn của hội viên',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PaymentSimulatorPage(
                      service: PaymentSimulatorService(service.api),
                    ),
                  ),
                ),
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

  const _SectionTitle({required this.title});

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
      ],
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
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
