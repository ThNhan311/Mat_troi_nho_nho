import 'package:flutter/material.dart';

class KioskIdleScreen extends StatelessWidget {
  const KioskIdleScreen({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const ColoredBox(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.face_retouching_natural,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'Vui lòng đứng trước camera để check-in',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}