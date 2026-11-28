import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'avatar.dart';

/// A trainer's round picture, with their initials until there is one.
class TrainerPhoto extends StatelessWidget {
  const TrainerPhoto({
    super.key,
    required this.api,
    required this.id,
    required this.name,
    required this.size,
  });

  final ApiClient api;
  final String id, name;
  final double size;

  @override
  Widget build(BuildContext context) => RemoteAvatar(
    api: api,
    path: '/trainers/$id/avatar',
    size: size,
    fallback: TrainerInitials(name, size: size),
  );
}

class TrainerInitials extends StatelessWidget {
  const TrainerInitials(this.name, {super.key, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        letters,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
