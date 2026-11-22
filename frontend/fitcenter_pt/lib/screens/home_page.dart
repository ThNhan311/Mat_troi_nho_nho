import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../services/booking_state.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import 'home_screen.dart';
import 'availability_page.dart';
import 'confirmed_sessions_page.dart';
import 'session_detail_page.dart';
import 'profile_page.dart';

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
  @override
  void initState() {
    super.initState();
    state.refresh();
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
      return Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: [
            HomeScreen(
              state: state,
              onOpenSchedule: () => _selectPage(1),
              onShowMessage: _showMessage,
              sessionCount: state.loaded ? sessions.length : null,
              memberCount: state.loaded
                  ? sessions.map((b) => b.memberId).toSet().length
                  : null,
            ),
            AvailabilityPage(state: state),
            ConfirmedSessionsPage(state: state, onOpenSession: openSession),
            const UnavailablePage(title: 'Giáo án'),
            ProfilePage(
              isDark: Theme.of(context).brightness == Brightness.dark,
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
    },
  );
}
