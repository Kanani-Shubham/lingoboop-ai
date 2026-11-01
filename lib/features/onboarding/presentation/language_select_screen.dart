import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/language_data.dart';
import '../../companion/presentation/companion_state.dart';

class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  ConsumerState<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen> {
  String _source = 'gu';
  String _target = 'en';

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Languages',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us what you speak and what you want to master.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 24),

              // Source Language Section
              Text(
                'I SPEAK',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: LanguageRegistry.languages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final l = LanguageRegistry.languages[i];
                    final isSel = l.code == _source;
                    return InkWell(
                      onTap: () => setState(() => _source = l.code),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.foxMaru : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? AppColors.foxMaru : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${l.flag} ${l.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Target Language Section
              Text(
                "I'M LEARNING",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: LanguageRegistry.languages.length,
                  itemBuilder: (context, i) {
                    final l = LanguageRegistry.languages[i];
                    final isSel = l.code == _target;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel ? AppColors.foxMaru : AppColors.borderSoft,
                          width: isSel ? 2.0 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        leading: Text(l.flag, style: const TextStyle(fontSize: 24)),
                        title: Text(
                          l.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: isSel
                            ? const Icon(Icons.check_circle, color: AppColors.foxMaru)
                            : null,
                        onTap: () => setState(() => _target = l.code),
                      ),
                    );
                  },
                ),
              ),

              // Continue Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.foxMaru,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    notifier.setSourceLanguage(_source);
                    notifier.setTargetLanguage(_target);
                    Navigator.pushNamed(context, '/onboarding/goals');
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
