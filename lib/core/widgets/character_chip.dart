import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CharacterChip extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeBorderColor;

  const CharacterChip({
    super.key,
    required this.label,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
    this.activeBorderColor = AppColors.foxMaru,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? activeBorderColor : AppColors.border,
              width: 2.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

