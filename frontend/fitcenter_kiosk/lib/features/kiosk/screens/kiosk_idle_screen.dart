import 'package:flutter/material.dart';

/// Màn hình chờ: chỉ camera, dòng hướng dẫn ở trên và logo ở góc phải dưới,
/// để người đứng trước máy nhìn rõ mặt mình.
class KioskIdleScreen extends StatelessWidget {
  const KioskIdleScreen({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox.expand(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 32,
                left: 24,
                right: 24,
                child: Text(
                  'Vui lòng đứng trước camera để check-in',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
              Positioned(right: 24, bottom: 20, child: _Logo()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo giống app quản trị: quả tạ và chữ FITCENTER.
class _Logo extends StatelessWidget {
  const _Logo();

  static const Color _green = Color(0xFF9DBB78);

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fitness_center, size: 34, color: _green),
        SizedBox(width: 10),
        Text(
          'FITCENTER',
          style: TextStyle(
            color: _green,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}
