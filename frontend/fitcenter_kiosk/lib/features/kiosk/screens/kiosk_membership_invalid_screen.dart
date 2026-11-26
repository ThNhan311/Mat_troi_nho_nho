import 'package:flutter/material.dart';

class KioskMembershipInvalidScreen extends StatelessWidget {
  const KioskMembershipInvalidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 100, color: Colors.orangeAccent),
          SizedBox(height: 24),
          Text(
            'Membership không còn hiệu lực',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Vui lòng liên hệ nhân viên để được hỗ trợ.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
