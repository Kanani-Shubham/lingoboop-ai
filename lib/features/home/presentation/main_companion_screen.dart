import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/floating_pet_avatar.dart';
import '../../../core/widgets/polypet_bottom_nav.dart';
import '../../../core/widgets/polypet_card.dart';
import '../../companion/presentation/companion_state.dart';
import '../../companion/presentation/lingo_card_widget.dart';
import '../../settings/presentation/pet_settings_sheet.dart';

class MainCompanionScreen extends ConsumerStatefulWidget {
  const MainCompanionScreen({super.key});

  @override
  ConsumerState<MainCompanionScreen> createState() => _MainCompanionScreenState();
}

class _MainCompanionScreenState extends ConsumerState<MainCompanionScreen> {
  int _currentTabIndex = 0;
  Offset _petPos = const Offset(120, 360);
  bool _hasTappedPet = false;

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);
    final size = MediaQuery.of(context).size;

    // Floor baseline clamp matching prototype
    final maxY = size.height - 64 - 150;

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // 1. Primary Page Content (Notes Feed & Header)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Bar Simulation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '9:41',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                      ),
                      Text(
                        '5G 82%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                      ),
                    ],
                  ),
                ),

                // Action Header: "Notes" Title and Gear Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                      ),
                      // Gear Button (#gear)
                      InkWell(
                        onTap: notifier.toggleSettings,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border, width: 2.0),
                          ),
                          child: const Center(
                            child: Icon(Icons.settings, size: 20, color: AppColors.textDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Note Cards List (.n)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      PolyPetCard(
                        title: 'Groceries',
                        subtitle: 'Rice, ghee, mangoes, two lemons',
                        isOdd: false,
                        onTap: () {
                          notifier.openCard();
                          notifier.submitTypedText('Buy rice, ghee, mangoes, and two lemons.');
                        },
                      ),
                      PolyPetCard(
                        title: 'Train to Surat',
                        subtitle: 'Saturday, 7:40 am, platform 3',
                        isOdd: true,
                        onTap: () {
                          notifier.openCard();
                          notifier.submitTypedText('The train to Surat leaves at platform three.');
                        },
                      ),
                      PolyPetCard(
                        title: 'Call Dad',
                        subtitle: 'About Sunday lunch',
                        isOdd: false,
                        onTap: () {
                          notifier.openCard();
                          notifier.submitTypedText('Call Dad about Sunday lunch.');
                        },
                      ),
                      PolyPetCard(
                        title: 'Practice',
                        subtitle: 'Say it out loud, even if it sounds wrong',
                        isOdd: true,
                        onTap: () {
                          notifier.openCard();
                          notifier.startListening();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. Settings Sheet Dropdown (#sh)
            if (companionState.isSettingsOpen)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: const PetSettingsSheet(),
              ),

            // 3. Floating LingoCard Dialogue (#cd)
            if (companionState.isCardOpen) ...[
              // Docking placement logic from HTML prototype:
              // If pet is on left, card docks right; if on right, card docks left.
              Positioned(
                bottom: 84,
                left: _petPos.dx + 70 < size.width / 2 ? 120 : 16,
                right: _petPos.dx + 70 < size.width / 2 ? 16 : null,
                child: const LingoCardWidget(),
              ),
            ],

            // 4. Draggable Floating 3D Pet Companion (#pw / #cv)
            Positioned(
              left: _petPos.dx,
              top: _petPos.dy,
              child: FloatingPetAvatar(
                character: companionState.activePet,
                mode: companionState.petMode,
                showHint: !_hasTappedPet,
                onTap: () {
                  setState(() => _hasTappedPet = true);
                  notifier.toggleCard();
                },
                onDragUpdate: (delta) {
                  setState(() {
                    _petPos = Offset(
                      (_petPos.dx + delta.dx).clamp(-20.0, size.width - 120.0),
                      (_petPos.dy + delta.dy).clamp(60.0, maxY),
                    );
                  });
                  notifier.updatePetPosition(_petPos);
                },
                onDragEnd: () {
                  notifier.finishPetDrag();
                },
              ),
            ),

            // 5. Bottom Navigation Bar (.tb)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PolyPetBottomNav(
                currentIndex: _currentTabIndex,
                activeAccentColor: companionState.activePet.accentColor,
                onTabSelected: (index) {
                  setState(() => _currentTabIndex = index);
                  if (index == 1) {
                    Navigator.pushNamed(context, '/progress');
                  } else if (index == 2) {
                    Navigator.pushNamed(context, '/achievements');
                  } else if (index == 3) {
                    Navigator.pushNamed(context, '/profile');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
