import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/character_data.dart';
import '../../../core/constants/language_data.dart';
import '../../../core/widgets/character_chip.dart';
import '../../companion/presentation/companion_state.dart';

class PetSettingsSheet extends ConsumerWidget {
  const PetSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 36,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Pet and languages',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 12),

          // Source Language Selector ("I speak")
          _buildLanguageDropdown(
            label: 'I speak',
            currentCode: state.sourceLanguage.code,
            onChanged: (code) {
              if (code != null) notifier.setSourceLanguage(code);
            },
          ),
          const SizedBox(height: 10),

          // Target Language Selector ("I'm learning")
          _buildLanguageDropdown(
            label: "I'm learning",
            currentCode: state.targetLanguage.code,
            onChanged: (code) {
              if (code != null) notifier.setTargetLanguage(code);
            },
          ),
          const SizedBox(height: 14),

          // Pet Chips Row
          Text(
            'Choose your companion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CharacterRegistry.allCharacters.map((pet) {
              final isSelected = pet.key == state.activePet.key;
              return CharacterChip(
                label: pet.name,
                dotColor: pet.accentColor,
                isSelected: isSelected,
                activeBorderColor: state.activePet.accentColor,
                onTap: () => notifier.setPet(pet.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Done Button
          SizedBox(
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: state.activePet.accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: notifier.closeSettings,
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required String label,
    required String currentCode,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 2.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentCode,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textDark),
              items: LanguageRegistry.languages.map((l) {
                return DropdownMenuItem<String>(
                  value: l.code,
                  child: Row(
                    children: [
                      Text(l.flag),
                      const SizedBox(width: 8),
                      Text(
                        l.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

