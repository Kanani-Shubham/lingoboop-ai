import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/character_data.dart';
import '../../companion/presentation/companion_state.dart';

class PetSelectScreen extends ConsumerStatefulWidget {
  const PetSelectScreen({super.key});

  @override
  ConsumerState<PetSelectScreen> createState() => _PetSelectScreenState();
}

class _PetSelectScreenState extends ConsumerState<PetSelectScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characters = CharacterRegistry.allCharacters;
    final selectedPet = characters[_currentIndex];
    final notifier = ref.read(companionProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Your Buddy',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Each companion brings a distinct teaching personality.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3D Pet Showcase Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: characters.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) {
                  final pet = characters[i];
                  final isSelected = i == _currentIndex;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: isSelected ? 8 : 24,
                    ),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: pet.accentColor.withValues(alpha: isSelected ? 0.22 : 0.08),
                          blurRadius: isSelected ? 24 : 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: isSelected ? pet.accentColor : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pet Preview Image
                        Expanded(
                          child: Center(
                            child: Image.asset(
                              pet.previewAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Name and Species
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              pet.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: pet.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pet.species,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: pet.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Personality Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            pet.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Free or Premium indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pet.isFreeTier ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pet.isFreeTier ? 'Free Tier Pet' : 'Premium Tier (Unlockable)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: pet.isFreeTier ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Page Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(characters.length, (i) {
                final isSel = i == _currentIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSel ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSel ? selectedPet.accentColor : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // Choose Pet Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedPet.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    notifier.setPet(selectedPet.key);
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: Text(
                    'Adopt ${selectedPet.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
