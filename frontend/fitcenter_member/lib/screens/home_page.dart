import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../services/booking_state.dart';
import '../widgets/api_status.dart';
import 'home_screen.dart';
import 'schedule_page.dart';
import 'profile_page.dart';
import 'trainer_list_page.dart';
import 'booking_history_page.dart';

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
  void history() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => BookingHistoryPage(state: state),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeScreen(
            state: state,
            bookingConfirmed: state.bookings.any(
              (b) => b.status == 'CONFIRMED',
            ),
            bookingCount: state.loaded
                ? state.bookings.where((b) => b.status == 'CONFIRMED').length
                : null,
            onOpenSchedule: () => _selectPage(1),
            onOpenMembership: () => _selectPage(2),
            onShowMessage: _showMessage,
          ),
          SchedulePage(state: state),
          const UnavailablePage(title: 'Gói hội viên'),
          ProfilePage(
            isDark: Theme.of(context).brightness == Brightness.dark,
            onToggleTheme: widget.onToggleTheme,
            onShowMessage: _showMessage,
            onOpenMembership: () => _selectPage(2),
            onLogout: widget.onLogout,
            onOpenBookingHistory: history,
          ),
          TrainerListPage(
            state: state,
            onShowMessage: _showMessage,
            onSelectTrainerForBooking: (id) {
              _selectPage(1);
              state.selectTrainer(id);
            },
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
              label: 'Lịch tập',
            ),
            NavigationDestination(
              icon: Icon(Icons.card_membership_outlined),
              selectedIcon: Icon(Icons.card_membership),
              label: 'Gói hội viên',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'PT',
            ),
          ],
        ),
      ),
    ),
  );
}
