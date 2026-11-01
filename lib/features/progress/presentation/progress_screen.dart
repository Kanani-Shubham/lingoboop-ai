import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../companion/presentation/companion_state.dart';

class WordProgressItem {
  final String word;
  final String translation;
  final double masteryScore;
  final int repetitionCount;
  final bool isDue;

  const WordProgressItem({
    required this.word,
    required this.translation,
    required this.masteryScore,
    required this.repetitionCount,
    required this.isDue,
  });
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _activeFilter = 'all';

  final List<WordProgressItem> _words = const [
    WordProgressItem(
      word: 'ચોખા (Chokhā)',
      translation: 'Rice',
      masteryScore: 95.0,
      repetitionCount: 6,
      isDue: false,
    ),
    WordProgressItem(
      word: 'ઘી (Ghī)',
      translation: 'Clarified butter (Ghee)',
      masteryScore: 88.0,
      repetitionCount: 4,
      isDue: false,
    ),
    WordProgressItem(
      word: 'સુરતની ટ્રેન (Suratnī ṭrēna)',
      translation: 'Train to Surat',
      masteryScore: 62.0,
      repetitionCount: 2,
      isDue: true,
    ),
    WordProgressItem(
      word: 'બપોરનું ભોજન (Bapōranũ bhōjana)',
      translation: 'Lunch',
      masteryScore: 45.0,
      repetitionCount: 1,
      isDue: true,
    ),
    WordProgressItem(
      word: 'મોટેથી બોલો (Mōṭēthī bōlō)',
      translation: 'Speak out loud',
      masteryScore: 78.0,
      repetitionCount: 3,
      isDue: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);

    final filtered = _words.where((w) {
      if (_activeFilter == 'due') return w.isDue;
      if (_activeFilter == 'mastered') return w.masteryScore >= 80;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Learning Progress',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(18),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryMetric('Total Words', '${_words.length}'),
                    _buildSummaryMetric('Due Today', '${_words.where((w) => w.isDue).length}'),
                    _buildSummaryMetric('Mastered', '${_words.where((w) => w.masteryScore >= 80).length}'),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('All Words', 'all', state.activePet.accentColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('Due for Review', 'due', state.activePet.accentColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('Mastered', 'mastered', state.activePet.accentColor),
                ],
              ),

              const SizedBox(height: 14),

              // Word Cards List
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.isDue ? state.activePet.accentColor.withValues(alpha: 0.5) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.word,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.translation,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Mastery: ${item.masteryScore.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: state.activePet.accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Reps: ${item.repetitionCount}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (item.isDue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.activePet.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Review Due',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: state.activePet.accentColor,
                                ),
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
    );
  }

  Widget _buildSummaryMetric(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String key, Color accent) {
    final isSel = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? accent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSel ? accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSel ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
