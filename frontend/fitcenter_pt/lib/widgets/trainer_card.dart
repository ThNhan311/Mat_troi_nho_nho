import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.experience,
    required this.avatarIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String specialty;
  final String experience;
  final IconData avatarIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.green : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.green.withValues(alpha: 0.15),
                child: Icon(
                  avatarIcon,
                  color: AppColors.green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      specialty,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? AppColors.green
                    : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
