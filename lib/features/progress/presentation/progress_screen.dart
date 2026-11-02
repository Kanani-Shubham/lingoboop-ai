import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_data_service.dart';
import '../../companion/presentation/companion_state.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _activeFilter = 'all';
  bool _isLoading = true;
  List<Map<String, dynamic>> _progressItems = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final items = await UserDataService.instance.getLearningProgress();
    if (mounted) {
      setState(() {
        _progressItems = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);

    final filteredItems = _progressItems.where((item) {
      final score = (item['mastery_score'] as num?)?.toDouble() ?? 0.0;
      if (_activeFilter == 'due') {
        final nextReview = DateTime.tryParse(item['next_review_at']?.toString() ?? '');
        return nextReview != null && nextReview.isBefore(DateTime.now());
      } else if (_activeFilter == 'mastered') {
        return score >= 85.0;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Learning Progress',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProgress,
          color: companionState.activePet.accentColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Summary Stats Card (Calculated from real records)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSoft, width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        title: 'Words Learned',
                        value: '${_progressItems.length}',
                        color: companionState.activePet.accentColor,
                      ),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _buildMetric(
                        title: 'Mastered',
                        value: '${_progressItems.where((i) => ((i['mastery_score'] as num?)?.toDouble() ?? 0.0) >= 85).length}',
                        color: AppColors.catMimi,
                      ),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _buildMetric(
                        title: 'To Review',
                        value: '${_progressItems.where((i) {
                          final nr = DateTime.tryParse(i['next_review_at']?.toString() ?? '');
                          return nr != null && nr.isBefore(DateTime.now());
                        }).length}',
                        color: AppColors.foxMaru,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Words', 'all', companionState.activePet.accentColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ready to Review', 'due', companionState.activePet.accentColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('Mastered', 'mastered', companionState.activePet.accentColor),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Vocabulary List / Empty State
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories_outlined,
                                    size: 54,
                                    color: AppColors.textMuted.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No words recorded yet',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      'Practice speaking with your buddy. New vocabulary will automatically be saved for spaced repetition review here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMuted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (context, i) {
                                final item = filteredItems[i];
                                final word = item['word_phrase']?.toString() ?? '';
                                final trans = item['translation']?.toString() ?? '';
                                final score = (item['mastery_score'] as num?)?.toDouble() ?? 0.0;
                                final reps = (item['repetition_count'] as num?)?.toInt() ?? 1;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.borderSoft, width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              word,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              trans,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${score.toInt()}%',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: score >= 80
                                                  ? AppColors.catMimi
                                                  : score >= 50
                                                      ? AppColors.foxMaru
                                                      : AppColors.textMuted,
                                            ),
                                          ),
                                          Text(
                                            '$reps reps',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
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

  Widget _buildMetric({required String title, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
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
