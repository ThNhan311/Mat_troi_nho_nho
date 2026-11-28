import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../services/booking_state.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import '../widgets/avatar.dart';
import 'home_screen.dart';
import 'availability_page.dart';
import 'confirmed_sessions_page.dart';
import 'session_detail_page.dart';
import 'profile_page.dart';
import '../services/password_service.dart';
import 'change_password_page.dart';
import '../services/pt_profile_service.dart';
import 'trainer_profile_page.dart';
import '../widgets/success_popup.dart';

class HomePage extends StatefulWidget {
  final BookingService service;
  final VoidCallback onLogout;
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;
  const HomePage({
    super.key,
    required this.service,
    required this.onLogout,
    required this.isDark,
    required this.onToggleTheme,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final BookingState state = BookingState(widget.service);
  int selectedIndex = 0;
  Uint8List? photo;
  String? name;
  String? profileId;
  @override
  void initState() {
    super.initState();
    state.refresh();
    _loadPhoto();
    _loadName();
  }

  Future<void> _loadName() async {
    final profile = await widget.service.api.myProfile();
    if (!mounted) return;
    setState(() {
      name = profile.name;
      profileId = profile.profileId;
    });
  }

  Future<void> _loadPhoto() async {
    try {
      // A decorative picture must never renew or end the session by itself.
      final image = await widget.service.api.picture(
        'GET',
        renewSession: false,
      );
      if (mounted) setState(() => photo = image);
    } catch (_) {
      // The header keeps the default icon.
    }
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    if (state.busy) return;
    setState(() => selectedIndex = index);
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
  void openSession(Map<String, dynamic> selected) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final current = state.sessions
              .where((s) => s['id'] == selected['id'])
              .firstOrNull;
          return current == null
              ? const UnavailablePage(
                  title: 'Buổi tập không còn trong danh sách',
                )
              : SessionDetailPage(state: state, session: current);
        },
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final today = vietnamDate(DateTime.now().toUtc());
      final sessions = state.bookings
          .where(
            (b) => sameVietnamDay(b.startAt, today) && b.status == 'CONFIRMED',
          )
          .toList();
      return SuccessPopupHost(
        state: state,
        child: Scaffold(
          body: IndexedStack(
            index: selectedIndex,
            children: [
              HomeScreen(
                state: state,
                name: name,
                photo: photo,
                onOpenProfile: () => _selectPage(3),
                onOpenSchedule: () => _selectPage(1),
                onOpenSessions: () => _selectPage(2),
                onShowMessage: _showMessage,
                sessionCount: state.loaded ? sessions.length : null,
                memberCount: state.loaded
                    ? sessions.map((b) => b.memberId).toSet().length
                    : null,
              ),
              AvailabilityPage(state: state, active: selectedIndex == 1),
              ConfirmedSessionsPage(state: state, onOpenSession: openSession),
              ProfilePage(
                name: name,
                profileId: profileId,
                avatar: AvatarEditor(
                  api: widget.service.api,
                  size: 96,
                  active: selectedIndex == 3,
                  onMessage: _showMessage,
                  onChanged: (image) => setState(() => photo = image),
                ),
                isDark: Theme.of(context).brightness == Brightness.dark,
                onToggleTheme: widget.onToggleTheme,
                onShowMessage: _showMessage,
                onOpenSchedule: () => _selectPage(1),
                onOpenSessions: () => _selectPage(2),
                onLogout: widget.onLogout,
                onEditProfile: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TrainerProfilePage(
                      service: PtProfileService(widget.service.api),
                    ),
                  ),
                ),
                onChangePassword: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangePasswordPage(
                      service: PasswordService(widget.service.api),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                (states) =>
                    IconThemeData(color: Theme.of(context).colorScheme.primary),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                (states) => TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                ),
              ),
            ),
            child: NavigationBar(
              height: 72,
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.15),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Cá nhân',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
