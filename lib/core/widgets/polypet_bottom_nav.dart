import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PolyPetBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final Color activeAccentColor;

  const PolyPetBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.activeAccentColor = AppColors.foxMaru,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.borderSoft, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(index: 0, icon: Icons.chat_bubble_outline),
          _buildNavItem(index: 1, icon: Icons.trending_up),
          _buildNavItem(index: 2, icon: Icons.emoji_events_outlined),
          _buildNavItem(index: 3, icon: Icons.person_outline),
        ],
      ),
    );
  }

  Widget _buildNavItem({required int index, required IconData icon}) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected ? activeAccentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

