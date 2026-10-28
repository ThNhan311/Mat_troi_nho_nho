import 'package:flutter/material.dart';

class KioskSleepingScreen extends StatelessWidget {
  const KioskSleepingScreen({
    super.key,
    required this.onWake,
  });

  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onWake,
      child: const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bedtime_outlined,
                size: 72,
                color: Colors.white54,
              ),
              SizedBox(height: 20),
              Text(
                'FitCenter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}