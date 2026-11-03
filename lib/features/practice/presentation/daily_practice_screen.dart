import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/user_data_service.dart';
import '../../../core/utils/pronunciation_scorer.dart';
import '../../companion/presentation/companion_state.dart';

class DailySpeakingPracticeScreen extends ConsumerStatefulWidget {
  const DailySpeakingPracticeScreen({super.key});

  @override
  ConsumerState<DailySpeakingPracticeScreen> createState() =>
      _DailySpeakingPracticeScreenState();
}

class _DailySpeakingPracticeScreenState
    extends ConsumerState<DailySpeakingPracticeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sentences = [];
  int _currentIndex = 0;

  bool _isPlayingAudio = false;
  bool _isListening = false;
  bool _isAnalyzing = false;
  String? _userSpokenText;
  PronunciationResult? _scoringResult;

  final Map<int, int> _scores = {};
  final Set<int> _reviewIndices = {};

  @override
  void initState() {
    super.initState();
    _loadDailySentences();
  }

  String get _todayCacheKey {
    final now = DateTime.now();
    return 'daily_practice_${now.year}_${now.month}_${now.day}';
  }

  Future<void> _loadDailySentences() async {
    setState(() => _isLoading = true);
    final companionState = ref.read(companionProvider);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${docDir.path}/$_todayCacheKey.json');

      if (await cacheFile.exists()) {
        final cachedJson = await cacheFile.readAsString();
        if (cachedJson.isNotEmpty) {
          final decoded = jsonDecode(cachedJson) as List<dynamic>;
          if (decoded.isNotEmpty) {
            setState(() {
              _sentences = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Fetch from backend
      final fetched = await SpeechService.instance.fetchDailyPractice(
        nativeLang: companionState.sourceLanguage.bcp47,
        targetLang: companionState.targetLanguage.bcp47,
        count: 20,
      );

      if (fetched.isNotEmpty) {
        await cacheFile.writeAsString(jsonEncode(fetched));
      }

      if (mounted) {
        setState(() {
          _sentences = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DailyPractice] Error loading sentences: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? get _currentSentence =>
      (_sentences.isNotEmpty && _currentIndex < _sentences.length)
          ? _sentences[_currentIndex]
          : null;

  Future<void> _playSentenceAudio(double speed) async {
    final item = _currentSentence;
    if (item == null || _isPlayingAudio) return;

    final sentence = item['target_sentence']?.toString() ?? '';
    if (sentence.isEmpty) return;

    setState(() => _isPlayingAudio = true);

    try {
      final companionState = ref.read(companionProvider);
      final wavPath = await SpeechService.instance.synthesizeTTS(
        text: sentence,
        languageCode: companionState.targetLanguage.bcp47,
        speed: speed,
      );

      if (wavPath != null) {
        await SpeechService.instance.playAudioFile(wavPath, speed: speed);
      }
    } catch (e) {
      debugPrint('[DailyPractice] TTS audio error: $e');
    } finally {
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  Future<void> _toggleSpeaking() async {
    if (_isListening) {
      // Stop recording and score
      setState(() {
        _isListening = false;
        _isAnalyzing = true;
      });

      final item = _currentSentence;
      final expected = item?['target_sentence']?.toString() ?? '';

      final audioPath = await SpeechService.instance.stopRecording();
      String userSpoken = '';

      if (audioPath != null) {
        final companionState = ref.read(companionProvider);
        final transcript = await SpeechService.instance.transcribeAudio(
          audioPath: audioPath,
          languageCode: companionState.targetLanguage.bcp47,
        );
        userSpoken = transcript ?? '';
      }

      final scoring = PronunciationScorer.evaluate(
        expectedSentence: expected,
        spokenTranscript: userSpoken,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _userSpokenText = userSpoken;
          _scoringResult = scoring;
          if (scoring.hasSpoken) {
            _scores[_currentIndex] = scoring.matchPercentage;
          }
        });

        // Record progress in database
        if (scoring.hasSpoken) {
          final companionState = ref.read(companionProvider);
          UserDataService.instance.recordConversationMessage(
            characterId: companionState.activePet.key,
            sourceLanguage: companionState.sourceLanguage.bcp47,
            targetLanguage: companionState.targetLanguage.bcp47,
            sourceText: item?['native_translation']?.toString() ?? '',
            translatedText: expected,
            pronunciationScore: scoring.matchPercentage.toDouble(),
          );
        }
      }
    } else {
      // Start recording
      final started = await SpeechService.instance.startRecording();
      if (started && mounted) {
        setState(() {
          _isListening = true;
          _scoringResult = null;
          _userSpokenText = null;
        });
      }
    }
  }

  void _nextSentence() {
    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _scoringResult = null;
        _userSpokenText = null;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previousSentence() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _scoringResult = null;
        _userSpokenText = null;
      });
    }
  }

  void _toggleReviewCurrent() {
    setState(() {
      if (_reviewIndices.contains(_currentIndex)) {
        _reviewIndices.remove(_currentIndex);
      } else {
        _reviewIndices.add(_currentIndex);
      }
    });
  }

  void _showCompletionDialog() {
    final total = _sentences.length;
    final attempted = _scores.length;
    final avgScore = attempted > 0
        ? (_scores.values.reduce((a, b) => a + b) / attempted).round()
        : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎉 Practice Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You finished today\'s daily speaking set!'),
            const SizedBox(height: 12),
            Text('• Sentences Practiced: $attempted / $total'),
            Text('• Average Pronunciation: $avgScore%'),
            if (_reviewIndices.isNotEmpty)
              Text('• Saved for Review: ${_reviewIndices.length} sentences'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);
    final petAccent = companionState.activePet.accentColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.phoneBackground,
        appBar: AppBar(
          title: const Text('Daily Speech Practice'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: petAccent),
              const SizedBox(height: 16),
              const Text(
                'Generating customized sentences via Groq AI…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final item = _currentSentence;
    if (item == null) {
      return Scaffold(
        backgroundColor: AppColors.phoneBackground,
        appBar: AppBar(title: const Text('Daily Practice')),
        body: const Center(child: Text('No practice sentences available.')),
      );
    }

    final targetSentence = item['target_sentence']?.toString() ?? '';
    final nativeTranslation = item['native_translation']?.toString() ?? '';
    final category = item['category']?.toString() ?? 'General';
    final guide = item['pronunciation_guide']?.toString() ?? '';
    final tip = item['context_tip']?.toString() ?? '';

    final currentScore = _scores[_currentIndex];
    final isSavedForReview = _reviewIndices.contains(_currentIndex);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daily Speaking Practice',
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSavedForReview ? Icons.bookmark : Icons.bookmark_border,
              color: isSavedForReview ? petAccent : AppColors.textMuted,
            ),
            tooltip: 'Save for Review',
            onPressed: _toggleReviewCurrent,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Strip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sentence ${_currentIndex + 1} of ${_sentences.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (currentScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: currentScore >= 75
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$currentScore% Match',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: currentScore >= 75
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _sentences.length,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(petAccent),
                    ),
                  ),
                ],
              ),
            ),

            // Main Practice Card
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderSoft, width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: petAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: petAccent,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Word-Level Evaluated or Target Sentence
                        if (_scoringResult != null && _scoringResult!.hasSpoken)
                          _buildEvaluatedWordsDisplay(_scoringResult!, petAccent)
                        else
                          Text(
                            targetSentence,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.35,
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Native Meaning
                        Text(
                          nativeTranslation,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (guide.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.record_voice_over, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  guide,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (tip.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x0C000000),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text('💡 ', style: TextStyle(fontSize: 14)),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // Audio Listen Buttons
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isPlayingAudio ? null : () => _playSentenceAudio(1.0),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: petAccent, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.volume_up, size: 18),
                              label: const Text('Listen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isPlayingAudio ? null : () => _playSentenceAudio(0.75),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.slow_motion_video, size: 18, color: AppColors.textDark),
                              label: const Text('Slow', style: TextStyle(fontSize: 13, color: AppColors.textDark)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Evaluation Feedback Container
                  if (_isAnalyzing)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Evaluating your pronunciation…', style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    )
                  else if (_scoringResult != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _scoringResult!.matchPercentage >= 70
                            ? Colors.green.shade50
                            : (_scoringResult!.hasSpoken ? Colors.orange.shade50 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _scoringResult!.matchPercentage >= 70
                              ? Colors.green.shade200
                              : (_scoringResult!.hasSpoken ? Colors.orange.shade200 : Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _scoringResult!.matchPercentage >= 70
                                    ? Icons.check_circle
                                    : (_scoringResult!.hasSpoken ? Icons.warning : Icons.info_outline),
                                size: 18,
                                color: _scoringResult!.matchPercentage >= 70
                                    ? Colors.green.shade700
                                    : (_scoringResult!.hasSpoken ? Colors.orange.shade800 : AppColors.textMuted),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _scoringResult!.feedbackMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _scoringResult!.matchPercentage >= 70
                                        ? Colors.green.shade800
                                        : (_scoringResult!.hasSpoken ? Colors.orange.shade900 : AppColors.textDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_userSpokenText != null && _userSpokenText!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Heard: "$_userSpokenText"',
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Speaking Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: _currentIndex > 0 ? AppColors.textDark : AppColors.border,
                    onPressed: _currentIndex > 0 ? _previousSentence : null,
                  ),

                  // Center Mic Record Button
                  GestureDetector(
                    onTap: _isAnalyzing ? null : _toggleSpeaking,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red : petAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : petAccent).withValues(alpha: 0.35),
                            blurRadius: _isListening ? 18 : 10,
                            spreadRadius: _isListening ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  // Next button
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    color: AppColors.textDark,
                    onPressed: _nextSentence,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluatedWordsDisplay(PronunciationResult result, Color accent) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: result.wordResults.map((wr) {
        Color bg;
        Color textColor;
        TextDecoration? decoration;

        switch (wr.status) {
          case WordAccuracyStatus.correct:
            bg = Colors.green.shade100;
            textColor = Colors.green.shade900;
            break;
          case WordAccuracyStatus.partial:
            bg = Colors.orange.shade100;
            textColor = Colors.orange.shade900;
            break;
          case WordAccuracyStatus.missed:
            bg = Colors.red.shade50;
            textColor = Colors.red.shade900;
            decoration = TextDecoration.underline;
            break;
          case WordAccuracyStatus.extra:
            bg = Colors.grey.shade200;
            textColor = Colors.black54;
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            wr.word,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
              decoration: decoration,
              decorationColor: Colors.red,
            ),
          ),
        );
      }).toList(),
    );
  }
}
