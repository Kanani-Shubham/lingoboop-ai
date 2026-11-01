import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_data_service.dart';
import '../../companion/presentation/companion_state.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final convs = await UserDataService.instance.getConversations();
    if (mounted) {
      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'History',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 22,
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
        child: RefreshIndicator(
          onRefresh: _loadConversations,
          color: state.activePet.accentColor,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 54,
                              color: AppColors.textMuted.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No conversations yet',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your spoken sentences, translations, and pronunciation practice will be recorded here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _conversations.length,
                      itemBuilder: (context, i) {
                        final conv = _conversations[i];
                        final title = conv['title']?.toString() ?? 'Session';
                        final srcLang = conv['source_language']?.toString() ?? '';
                        final tgtLang = conv['target_language']?.toString() ?? '';
                        final messages = (conv['messages'] as List?) ?? [];
                        final firstMsg = messages.isNotEmpty ? messages.first : null;
                        final sourceText = firstMsg != null ? firstMsg['source_text']?.toString() ?? title : title;
                        final translatedText = firstMsg != null ? firstMsg['translated_text']?.toString() ?? '' : '';
                        final score = firstMsg != null ? (firstMsg['pronunciation_score'] as num?)?.toDouble() : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderSoft, width: 1.0),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$srcLang → $tgtLang',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: state.activePet.accentColor,
                                    ),
                                  ),
                                  if (score != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: score >= 85
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: score >= 85
                                              ? Colors.green.shade200
                                              : Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        'Score: ${score.toInt()}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: score >= 85
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sourceText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (translatedText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  translatedText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Practice Again', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: state.activePet.accentColor,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                  ),
                                  onPressed: () {
                                    notifier.openCard();
                                    notifier.submitTypedText(translatedText.isNotEmpty ? translatedText : sourceText);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
