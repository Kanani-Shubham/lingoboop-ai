import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/karaoke_lyrics_view.dart';
import '../../../core/widgets/polypet_button.dart';
import '../../../core/widgets/polypet_mic_button.dart';
import 'companion_state.dart';

class LingoCardWidget extends ConsumerStatefulWidget {
  const LingoCardWidget({super.key});

  @override
  ConsumerState<LingoCardWidget> createState() => _LingoCardWidgetState();
}

class _LingoCardWidgetState extends ConsumerState<LingoCardWidget> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);

    final langPairText =
        '${state.sourceLanguage.name.split(' ')[0]} → ${state.targetLanguage.name}';

    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: state.activePet.accentColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Name, Language Pair, Close Button
          Row(
            children: [
              Text(
                state.activePet.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  langPairText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: notifier.closeCard,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0x33FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          // Spoken Transcript (Source text)
          if (state.spokenText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              state.spokenText,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Synced Karaoke Words (#lyr)
          const SizedBox(height: 6),
          KaraokeLyricsView(words: state.words),

          // Status / Evaluation note (#nt)
          if (state.statusNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.statusNote,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Control Strip: Play, Slow, Repeat, Mic
          Row(
            children: [
              // Play
              PolyPetButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                onPressed: () => notifier.playKaraoke(1.0),
              ),
              const SizedBox(width: 6),

              // Slow (0.7x)
              PolyPetButton(
                label: 'Slow',
                onPressed: () => notifier.playKaraoke(0.7),
              ),
              const SizedBox(width: 6),

              // Repeat Practice
              PolyPetButton(
                label: 'Repeat',
                onPressed: notifier.startRepeatPractice,
              ),

              const Spacer(),

              // Microphone Button
              PolyPetMicButton(
                isListening: state.isListening,
                accentColor: state.activePet.accentColor,
                onTap: () {
                  if (state.isListening) {
                    notifier.stopListeningAndProcess("સુરત જવાની ટ્રેન ક્યારે છે?");
                  } else {
                    notifier.startListening();
                    // Auto-finish after 2 seconds for interactive feel
                    Future.delayed(const Duration(seconds: 2), () {
                      if (ref.read(companionProvider).isListening) {
                        notifier.stopListeningAndProcess("સુરત જવાની ટ્રેન ક્યારે છે?");
                      }
                    });
                  }
                },
              ),
            ],
          ),

          // Fallback text input field
          const SizedBox(height: 10),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Or type a sentence...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.white60),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (val) {
                      notifier.submitTypedText(val);
                      _textController.clear();
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    notifier.submitTypedText(_textController.text);
                    _textController.clear();
                  },
                  child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

