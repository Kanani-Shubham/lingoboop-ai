import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/polypet_bottom_nav.dart';
import '../../achievements/presentation/achievements_screen.dart';
import '../../companion/presentation/companion_state.dart';
import '../../home/presentation/main_companion_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../progress/presentation/progress_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MainCompanionScreen(),
    ProgressScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: PolyPetBottomNav(
        currentIndex: _currentIndex,
        activeAccentColor: companionState.activePet.accentColor,
        onTabSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
