import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_data_service.dart';
import '../../companion/presentation/companion_state.dart';

class AchievementBadgeDefinition {
  final String code;
  final String title;
  final String description;
  final IconData icon;

  const AchievementBadgeDefinition({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _unlockedMap = {};

  static const List<AchievementBadgeDefinition> _catalog = [
    AchievementBadgeDefinition(
      code: 'first_word',
      title: 'First Word',
      description: 'Speak your first translated sentence.',
      icon: Icons.mic_none,
    ),
    AchievementBadgeDefinition(
      code: 'streak_3',
      title: 'Consistency Star',
      description: 'Practice 3 days in a row.',
      icon: Icons.local_fire_department,
    ),
    AchievementBadgeDefinition(
      code: 'pronunciation_pro',
      title: 'Pronunciation Pro',
      description: 'Score 100% on a speech repetition challenge.',
      icon: Icons.verified,
    ),
    AchievementBadgeDefinition(
      code: 'streak_7',
      title: 'Weekly Warrior',
      description: 'Reach a 7-day practice streak.',
      icon: Icons.military_tech,
    ),
    AchievementBadgeDefinition(
      code: 'polyglot_50',
      title: 'Vocabulary Builder',
      description: 'Learn and review 50 unique phrases.',
      icon: Icons.workspace_premium,
    ),
    AchievementBadgeDefinition(
      code: 'audio_master',
      title: 'Master Listener',
      description: 'Listen to 100 sentences spoken in normal and slow speeds.',
      icon: Icons.headphones,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    final userAchievements = await UserDataService.instance.getAchievements();
    final map = <String, dynamic>{};
    for (final a in userAchievements) {
      if (a['achievement_code'] != null) {
        map[a['achievement_code'].toString()] = a;
      }
    }
    if (mounted) {
      setState(() {
        _unlockedMap = map;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);
    final unlockedCount = _unlockedMap.length;

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Achievements',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAchievements,
          color: companionState.activePet.accentColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Hero Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.borderSoft, width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: companionState.activePet.accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.emoji_events,
                            size: 28,
                            color: companionState.activePet.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$unlockedCount of ${_catalog.length} Unlocked',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unlockedCount == 0
                                  ? 'Practice with your pet to unlock milestone badges.'
                                  : 'Great job! Keep practicing to earn more badges.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'BADGES & MILESTONES',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          itemCount: _catalog.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.88,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, i) {
                            final b = _catalog[i];
                            final isUnlocked = _unlockedMap.containsKey(b.code);

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isUnlocked
                                      ? companionState.activePet.accentColor.withValues(alpha: 0.5)
                                      : AppColors.borderSoft,
                                  width: isUnlocked ? 2.0 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isUnlocked
                                          ? companionState.activePet.accentColor
                                          : AppColors.border,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        b.icon,
                                        size: 24,
                                        color: isUnlocked ? Colors.white : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    b.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isUnlocked ? AppColors.textDark : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    b.description,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isUnlocked ? 'Unlocked' : 'Locked',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isUnlocked
                                          ? companionState.activePet.accentColor
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
