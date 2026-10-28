
import 'dart:async';

import 'package:flutter/material.dart';

import 'kiosk_state.dart';
import 'screens/kiosk_idle_screen.dart';
import 'screens/kiosk_capturing_screen.dart';
import 'screens/kiosk_recognizing_screen.dart';
import 'screens/kiosk_success_screen.dart';
import 'screens/kiosk_membership_invalid_screen.dart';
import 'screens/kiosk_no_match_screen.dart';
import 'screens/kiosk_sleeping_screen.dart';
import 'services/kiosk_checkin_service.dart';

class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final KioskCheckinService _checkinService = KioskCheckinService();

  KioskState _state = KioskState.idle;

  Timer? _idleTimer;
  Timer? _resultTimer;

  String _memberName = 'Nguyễn Văn A';
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _resultTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();

    if (_state == KioskState.sleeping) return;

    // Không tự chuyển màn hình khi đang xử lý check-in.
    if (_state == KioskState.capturing ||
        _state == KioskState.recognizing) {
      return;
    }

    _idleTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;

      setState(() {
        _state = KioskState.sleeping;
      });
    });
  }

  void _setStateAndResetTimer(KioskState state) {
    setState(() {
      _state = state;
    });

    _resetIdleTimer();
  }

  void _wakeKiosk() {
    _retryCount = 0;
    _setStateAndResetTimer(KioskState.idle);
  }

  Future<void> _startCheckIn() async {
    _idleTimer?.cancel();
    _resultTimer?.cancel();

    setState(() {
      _state = KioskState.capturing;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted || _state != KioskState.capturing) return;

    setState(() {
      _state = KioskState.recognizing;
    });

    try {
      final response = await _checkinService.checkIn();

      if (!mounted || _state != KioskState.recognizing) return;

      switch (response.result) {
        case CheckInResult.success:
          setState(() {
            _state = KioskState.success;
            _memberName = response.memberName ?? 'Hội viên';
          });
          break;

        case CheckInResult.membershipInvalid:
          setState(() {
            _state = KioskState.membershipInvalid;
          });
          break;

        case CheckInResult.noMatch:
          setState(() {
            _state = KioskState.noMatch;
          });
          break;
      }
    } catch (_) {
      if (!mounted || _state != KioskState.recognizing) return;

      setState(() {
        _state = KioskState.noMatch;
      });
    }

    _startResultTimer();
  }

  void _startResultTimer() {
    _resultTimer?.cancel();

    _resultTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _wakeKiosk();
    });
  }

  void _retryCheckIn() {
    _retryCount++;

    if (_retryCount > 3) {
      _wakeKiosk();
      return;
    }

    _startCheckIn();
  }

  void _showTestMenu() {
    _idleTimer?.cancel();
    _resultTimer?.cancel();

    showMenu<KioskState>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 40, 8, 0),
      items: const [
        PopupMenuItem(
          value: KioskState.idle,
          child: Text('Idle - Màn hình chờ'),
        ),
        PopupMenuItem(
          value: KioskState.capturing,
          child: Text('Capturing - Đang chụp ảnh'),
        ),
        PopupMenuItem(
          value: KioskState.recognizing,
          child: Text('Recognizing - Đang xác minh'),
        ),
        PopupMenuItem(
          value: KioskState.success,
          child: Text('Success - Thành công'),
        ),
        PopupMenuItem(
          value: KioskState.membershipInvalid,
          child: Text('Membership invalid'),
        ),
        PopupMenuItem(
          value: KioskState.noMatch,
          child: Text('No match - Không nhận diện'),
        ),
        PopupMenuItem(
          value: KioskState.sleeping,
          child: Text('Sleeping - Chế độ chờ'),
        ),
      ],
    ).then((selectedState) {
      if (!mounted || selectedState == null) return;

      setState(() {
        _state = selectedState;

        if (selectedState == KioskState.success) {
          _memberName = 'Nguyễn Văn A';
        }
      });

      _resetIdleTimer();
    });
  }

  Widget _buildCurrentScreen() {
    switch (_state) {
      case KioskState.idle:
        return KioskIdleScreen(onTap: _startCheckIn);

      case KioskState.sleeping:
        return KioskSleepingScreen(onWake: _wakeKiosk);

      case KioskState.capturing:
        return const KioskCapturingScreen();

      case KioskState.recognizing:
        return const KioskRecognizingScreen();

      case KioskState.success:
        return KioskSuccessScreen(memberName: _memberName);

      case KioskState.membershipInvalid:
        return const KioskMembershipInvalidScreen();

      case KioskState.noMatch:
        return KioskNoMatchScreen(onRetry: _retryCheckIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _resetIdleTimer,
              child: _buildCurrentScreen(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Menu kiểm thử',
                onPressed: _showTestMenu,
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
