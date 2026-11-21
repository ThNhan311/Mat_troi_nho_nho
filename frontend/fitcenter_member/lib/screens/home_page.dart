import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'schedule_page.dart';
import 'membership_page.dart';
import 'profile_page.dart';
import 'trainer_list_page.dart';
import 'booking_history_page.dart';

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

  String selectedTrainer = 'Nguyễn Minh Anh';
  String? selectedSlot;
  DateTime? selectedBookingDate;
  bool bookingConfirmed = false;
  bool isBookingSubmitting = false;

  // Lưu các lịch tập người dùng vừa đặt.
  final List<Map<String, String>> bookings = [];

  // Lưu lịch sử gia hạn trong phiên chạy demo.
  final List<Map<String, dynamic>> renewalHistory = [];

  // Thông tin gói hội viên hiện tại.
  Map<String, dynamic>? currentMembership;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  void _handlePaymentSuccess(Map<String, dynamic> payment) {
    final now = DateTime.now();

    // Lấy ngày hết hạn hiện tại, nếu có.
    final oldExpiryText = currentMembership?['expiryDate']?.toString();
    final oldExpiry = oldExpiryText == null
        ? null
        : DateTime.tryParse(oldExpiryText);

    // Nếu gói cũ còn hạn thì nối tiếp từ ngày hết hạn cũ.
    // Nếu chưa có gói hoặc đã hết hạn thì bắt đầu từ hôm nay.
    final startDate = oldExpiry != null && oldExpiry.isAfter(now)
        ? oldExpiry
        : now;

    final duration = payment['duration']?.toString() ?? '';
    final days = duration.contains('180')
        ? 180
        : duration.contains('90')
        ? 90
        : 30;

    final expiryDate = startDate.add(Duration(days: days));

    final updatedPayment = {
      ...payment,
      'startDate': startDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
    };

    setState(() {
      renewalHistory.insert(0, updatedPayment);

      currentMembership = {
        'planName': payment['planName'],
        'duration': duration,
        'price': payment['price'],
        'paidAt': payment['paidAt'],
        'startDate': startDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
      };
    });

    _showMessage('Gia hạn gói hội viên thành công!');
  }


  void _selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeScreen(
            bookingConfirmed: bookingConfirmed,
            onOpenSchedule: () => _selectPage(1),
            onOpenMembership: () => _selectPage(2),
            onShowMessage: _showMessage,
          ),
          SchedulePage(
            onDateSelected: (date) {
              setState(() {
                selectedBookingDate = date;
              });
            },
            selectedTrainer: selectedTrainer,
            selectedSlot: selectedSlot,
            bookingConfirmed: bookingConfirmed,
            isBookingSubmitting: isBookingSubmitting,
            onTrainerSelected: (trainer) {
              setState(() {
                selectedTrainer = trainer;
                selectedSlot = null;
              });
            },
            onSlotSelected: (slot) {
              setState(() {
                selectedSlot = slot;
              });
            },

            onBookingConfirmed: () {
              if (isBookingSubmitting || selectedSlot == null) return;

              final dateText = selectedBookingDate == null
                  ? ''
                  : '${selectedBookingDate!.day.toString().padLeft(2, '0')}/'
                  '${selectedBookingDate!.month.toString().padLeft(2, '0')}/'
                  '${selectedBookingDate!.year}';

              final isDuplicate = bookings.any((booking) =>
              booking['trainer'] == selectedTrainer &&
                  booking['date'] == dateText &&
                  booking['time'] == selectedSlot);

              if (isDuplicate) {
                _showMessage('Bạn đã đặt khung giờ này rồi!');
                return;
              }

              setState(() {
                isBookingSubmitting = true;
              });

              // Mô phỏng xử lý đặt lịch ở frontend.
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!mounted) return;

                setState(() {
                  bookings.insert(0, {
                    'trainer': selectedTrainer,
                    'date': dateText,
                    'time': selectedSlot!,
                    'status': 'CONFIRMED',
                  });

                  bookingConfirmed = true;
                  isBookingSubmitting = false;
                });

                _showMessage('Đặt lịch thành công!');
              });
            },

          ),
          MembershipPage(
            onShowMessage: _showMessage,
            onPaymentSuccess: _handlePaymentSuccess,
            currentMembership: currentMembership,
            renewalHistory: renewalHistory,
          ),
          ProfilePage(
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
            onShowMessage: _showMessage,
            onOpenMembership: () => _selectPage(2),
            onLogout: widget.onLogout,
            onOpenBookingHistory: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BookingHistoryPage(
                    bookings: bookings,
                    onShowMessage: _showMessage,
                  ),
                ),
              );
            },
          ),
          TrainerListPage(
            onShowMessage: _showMessage,
            onSelectTrainerForBooking: (trainer) {
              setState(() {
                selectedTrainer = trainer;
                selectedSlot = null;
                selectedIndex = 1;
              });
            },
          ),
        ],
      ),


      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                (states) => IconThemeData(
              color: Theme.of(context).colorScheme.primary,
            ),
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
          indicatorColor: Theme.of(context)
              .colorScheme
              .primary
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

    );
  }
}
