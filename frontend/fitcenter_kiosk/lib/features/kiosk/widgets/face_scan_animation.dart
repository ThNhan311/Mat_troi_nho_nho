import 'package:flutter/material.dart';

class FaceScanAnimation extends StatefulWidget {
  const FaceScanAnimation({super.key});

  @override
  State<FaceScanAnimation> createState() => _FaceScanAnimationState();
}

class _FaceScanAnimationState extends State<FaceScanAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 220,
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.greenAccent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Align(
            alignment: Alignment(
              0,
              -1 + (_controller.value * 2),
            ),
            child: Container(
              height: 3,
              color: Colors.greenAccent,
            ),
          ),
        );
      },
    );
  }
}