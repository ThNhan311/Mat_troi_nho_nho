import 'package:flutter/material.dart';

class KioskSuccessScreen extends StatelessWidget {
  const KioskSuccessScreen({
    super.key,
    required this.memberName,
  });

  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 100,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 24),
          Text(
            'Xin chào, $memberName!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Check-in thành công',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}