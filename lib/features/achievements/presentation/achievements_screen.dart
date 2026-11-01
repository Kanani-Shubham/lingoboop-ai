import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../companion/presentation/companion_state.dart';

class AchievementBadge {
  final String code;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final String? dateUnlocked;

  const AchievementBadge({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.dateUnlocked,
  });
}

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  final List<AchievementBadge> _badges = const [
    AchievementBadge(
      code: 'first_word',
      title: 'First Word',
      description: 'Spoke your first translated sentence.',
      icon: Icons.mic_external_on,
      isUnlocked: true,
      dateUnlocked: 'Yesterday',
    ),
    AchievementBadge(
      code: 'streak_3',
      title: 'Consistency Star',
      description: 'Practiced 3 days in a row.',
      icon: Icons.local_fire_department,
      isUnlocked: true,
      dateUnlocked: 'Today',
    ),
    AchievementBadge(
      code: 'pronunciation_pro',
      title: 'Pronunciation Pro',
      description: 'Scored 100% on a repeat-after-me challenge.',
      icon: Icons.verified,
      isUnlocked: true,
      dateUnlocked: 'Today',
    ),
    AchievementBadge(
      code: 'streak_7',
      title: 'Weekly Warrior',
      description: 'Reach a 7-day practice streak.',
      icon: Icons.military_tech,
      isUnlocked: false,
    ),
    AchievementBadge(
      code: 'polyglot_50',
      title: 'Vocabulary Master',
      description: 'Master 50 words in your target language.',
      icon: Icons.auto_stories,
      isUnlocked: false,
    ),
    AchievementBadge(
      code: 'pet_bestie',
      title: 'Pet Bestie',
      description: 'Hold 20 conversations with your companion.',
      icon: Icons.pets,
      isUnlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companionProvider);
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Achievements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          children: [
            // Header Trophy Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unlockedCount of ${_badges.length} Badges Earned',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Keep practicing to unlock pet dance celebrations!',
                          style: TextStyle(
                            fontSize: 13,
                            color: state.activePet.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Badges Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: _badges.length,
              itemBuilder: (context, i) {
                final b = _badges[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: b.isUnlocked ? state.activePet.accentColor.withValues(alpha: 0.4) : AppColors.borderSoft,
                      width: b.isUnlocked ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: b.isUnlocked
                              ? state.activePet.accentColor.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          b.icon,
                          size: 26,
                          color: b.isUnlocked ? state.activePet.accentColor : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        b.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: b.isUnlocked ? AppColors.textDark : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.25,
                        ),
                      ),
                      if (b.isUnlocked && b.dateUnlocked != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Unlocked ${b.dateUnlocked}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: state.activePet.accentColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
