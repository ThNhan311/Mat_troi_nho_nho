import 'package:flutter/material.dart';

class KioskNoMatchScreen extends StatelessWidget {
  const KioskNoMatchScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.face_unlock_outlined,
            size: 100,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 24),
          const Text(
            'Không nhận diện được',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Thử lại', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }
}
