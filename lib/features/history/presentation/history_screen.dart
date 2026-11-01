import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../companion/presentation/companion_state.dart';

class ConversationEntry {
  final String sourceText;
  final String translatedText;
  final String timestamp;
  final double? pronunciationScore;

  const ConversationEntry({
    required this.sourceText,
    required this.translatedText,
    required this.timestamp,
    this.pronunciationScore,
  });
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  final List<ConversationEntry> _entries = const [
    ConversationEntry(
      sourceText: 'સુરત જવાની ટ્રેન ક્યારે છે?',
      translatedText: 'The train to Surat leaves at platform three.',
      timestamp: 'Today, 9:42 AM',
      pronunciationScore: 92.0,
    ),
    ConversationEntry(
      sourceText: 'પપ્પાને ફોન કરજો.',
      translatedText: 'Let us call Dad about Sunday lunch.',
      timestamp: 'Today, 8:15 AM',
      pronunciationScore: 85.0,
    ),
    ConversationEntry(
      sourceText: 'ચોખા, ઘી અને કેરી ખરીદવી છે.',
      translatedText: 'Buy rice, ghee, mangoes, and two lemons.',
      timestamp: 'Yesterday, 6:30 PM',
      pronunciationScore: 98.0,
    ),
    ConversationEntry(
      sourceText: 'મોટેથી બોલો, ભલે ખોટું પડે.',
      translatedText: 'Say it out loud, even if it sounds wrong.',
      timestamp: 'Yesterday, 2:10 PM',
      pronunciationScore: 76.0,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Conversation History',
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
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          itemCount: _entries.length,
          itemBuilder: (context, i) {
            final entry = _entries[i];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.timestamp,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (entry.pronunciationScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Score: ${entry.pronunciationScore!.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.sourceText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.translatedText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.volume_up, size: 16, color: state.activePet.accentColor),
                        label: Text(
                          'Replay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: state.activePet.accentColor,
                          ),
                        ),
                        onPressed: () {
                          notifier.openCard();
                          notifier.submitTypedText(entry.translatedText);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

