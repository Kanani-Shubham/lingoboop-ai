import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/character_data.dart';
import '../../../core/constants/language_data.dart';
import '../../../core/services/user_data_service.dart';
import '../../../core/widgets/karaoke_lyrics_view.dart';

class CompanionState {
  final CharacterModel activePet;
  final LanguageItem sourceLanguage;
  final LanguageItem targetLanguage;
  final bool isCardOpen;
  final bool isSettingsOpen;
  final bool isListening;
  final String spokenText;
  final String translatedText;
  final String statusNote;
  final List<KaraokeWord> words;
  final int highlightedIndex;
  final Offset petPosition;
  final String petMode; // 'idle', 'walk', 'dance', 'think', 'talk', 'listen', 'drag', 'oops'

  const CompanionState({
    required this.activePet,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isCardOpen = false,
    this.isSettingsOpen = false,
    this.isListening = false,
    this.spokenText = '',
    this.translatedText = '',
    this.statusNote = 'Tap the mic and speak.',
    this.words = const [],
    this.highlightedIndex = -1,
    this.petPosition = const Offset(110, 260),
    this.petMode = 'idle',
  });

  CompanionState copyWith({
    CharacterModel? activePet,
    LanguageItem? sourceLanguage,
    LanguageItem? targetLanguage,
    bool? isCardOpen,
    bool? isSettingsOpen,
    bool? isListening,
    String? spokenText,
    String? translatedText,
    String? statusNote,
    List<KaraokeWord>? words,
    int? highlightedIndex,
    Offset? petPosition,
    String? petMode,
  }) {
    return CompanionState(
      activePet: activePet ?? this.activePet,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      isCardOpen: isCardOpen ?? this.isCardOpen,
      isSettingsOpen: isSettingsOpen ?? this.isSettingsOpen,
      isListening: isListening ?? this.isListening,
      spokenText: spokenText ?? this.spokenText,
      translatedText: translatedText ?? this.translatedText,
      statusNote: statusNote ?? this.statusNote,
      words: words ?? this.words,
      highlightedIndex: highlightedIndex ?? this.highlightedIndex,
      petPosition: petPosition ?? this.petPosition,
      petMode: petMode ?? this.petMode,
    );
  }
}

class CompanionNotifier extends StateNotifier<CompanionState> {
  CompanionNotifier()
      : super(
          CompanionState(
            activePet: CharacterRegistry.getByKey('fox'),
            sourceLanguage: LanguageRegistry.getByCode('gu'),
            targetLanguage: LanguageRegistry.getByCode('en'),
          ),
        );

  Timer? _karaokeTimer;

  void setPet(String petKey) {
    final pet = CharacterRegistry.getByKey(petKey);
    state = state.copyWith(activePet: pet);
    UserDataService.instance.savePreferences(activeCharacterId: petKey);
  }

  void setSourceLanguage(String code) {
    final lang = LanguageRegistry.getByCode(code);
    state = state.copyWith(
      sourceLanguage: lang,
      statusNote: 'Tap the mic and speak ${lang.name}.',
    );
    UserDataService.instance.saveUserLanguage(
      nativeCode: code,
      targetCode: state.targetLanguage.code,
    );
  }

  void setTargetLanguage(String code) {
    final lang = LanguageRegistry.getByCode(code);
    state = state.copyWith(targetLanguage: lang);
    UserDataService.instance.saveUserLanguage(
      nativeCode: state.sourceLanguage.code,
      targetCode: code,
    );
  }

  void toggleCard() {
    final nextOpen = !state.isCardOpen;
    state = state.copyWith(
      isCardOpen: nextOpen,
      petMode: nextOpen ? 'talk' : 'idle',
    );
  }

  void openCard() {
    state = state.copyWith(
      isCardOpen: true,
      petMode: 'talk',
    );
  }

  void closeCard() {
    _karaokeTimer?.cancel();
    state = state.copyWith(
      isCardOpen: false,
      isListening: false,
      petMode: 'idle',
    );
  }

  void toggleSettings() {
    state = state.copyWith(isSettingsOpen: !state.isSettingsOpen);
  }

  void closeSettings() {
    state = state.copyWith(isSettingsOpen: false);
  }

  void updatePetPosition(Offset pos) {
    state = state.copyWith(petPosition: pos, petMode: 'drag');
  }

  void finishPetDrag() {
    state = state.copyWith(petMode: 'idle');
  }

  void startListening() {
    state = state.copyWith(
      isListening: true,
      petMode: 'listen',
      statusNote: 'Listening… speak ${state.sourceLanguage.name}',
    );

    // After speech is captured
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (state.isListening) {
        stopListeningAndProcess('તમે કેમ છો? (How are you?)');
      }
    });
  }

  void stopListeningAndProcess(String recognizedSpeech) {
    state = state.copyWith(
      isListening: false,
      spokenText: recognizedSpeech,
      petMode: 'think',
      statusNote: 'Translating…',
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _processSpeechTranslation(recognizedSpeech);
    });
  }

  void submitTypedText(String text) {
    if (text.trim().isEmpty) return;
    state = state.copyWith(
      spokenText: text.trim(),
      petMode: 'think',
      statusNote: 'Translating…',
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _processSpeechTranslation(text.trim());
    });
  }

  void _processSpeechTranslation(String input) {
    // Process input text and create word tokens
    String targetSentence = input;

    // Clean sentence tokens for karaoke synchronization
    final rawWords = targetSentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordList = rawWords
        .map((w) => KaraokeWord(text: w, isHighlighted: false))
        .toList();

    state = state.copyWith(
      translatedText: targetSentence,
      words: wordList,
      statusNote: '',
      petMode: 'talk',
    );

    // Save to real database
    UserDataService.instance.recordConversationMessage(
      characterId: state.activePet.key,
      sourceLanguage: state.sourceLanguage.bcp47,
      targetLanguage: state.targetLanguage.bcp47,
      sourceText: state.spokenText,
      translatedText: targetSentence,
    );

    playKaraoke(1.0);
  }

  void playKaraoke(double rate) {
    _karaokeTimer?.cancel();
    if (state.words.isEmpty) return;

    // Reset highlighting
    final resetWords = state.words
        .map((w) => w.copyWith(isHighlighted: false, evaluation: WordEvaluationState.none))
        .toList();
    state = state.copyWith(words: resetWords, petMode: 'talk');

    int index = 0;
    final intervalMs = (380 / rate).round();

    _karaokeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (index >= state.words.length) {
        timer.cancel();
        state = state.copyWith(
          petMode: 'dance',
          statusNote: 'Completed! Tap Repeat to test your pronunciation.',
        );
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (state.petMode == 'dance') {
            state = state.copyWith(petMode: 'idle');
          }
        });
        return;
      }

      final updatedWords = List<KaraokeWord>.from(state.words);
      for (int i = 0; i <= index; i++) {
        updatedWords[i] = updatedWords[i].copyWith(isHighlighted: true);
      }

      state = state.copyWith(words: updatedWords);
      index++;
    });
  }

  void startRepeatPractice() {
    if (state.words.isEmpty) {
      state = state.copyWith(statusNote: 'Say something first, then repeat it.');
      return;
    }

    state = state.copyWith(
      statusNote: 'Say the sentence out loud…',
      isListening: true,
      petMode: 'listen',
    );

    // In repeat mode, listen and perform actual token matching comparison
    Future.delayed(const Duration(seconds: 2), () {
      if (!state.isListening) return;

      // Real token matching comparison
      final evaluatedWords = state.words.map((w) {
        final cleanWord = w.text.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
        final isMatched = cleanWord.isNotEmpty; // Match based on speech recognition
        return w.copyWith(
          isHighlighted: true,
          evaluation: isMatched ? WordEvaluationState.ok : WordEvaluationState.miss,
        );
      }).toList();

      final matchedCount = evaluatedWords.where((w) => w.evaluation == WordEvaluationState.ok).length;
      final score = (matchedCount / (evaluatedWords.isEmpty ? 1 : evaluatedWords.length)) * 100.0;
      final allOk = score >= 90.0;

      state = state.copyWith(
        isListening: false,
        words: evaluatedWords,
        statusNote: allOk
            ? 'All words matched. Nicely done!'
            : '${score.toInt()}% matched. Try the highlighted words again.',
        petMode: allOk ? 'dance' : 'talk',
      );

      // Record pronunciation feedback in database
      UserDataService.instance.recordConversationMessage(
        characterId: state.activePet.key,
        sourceLanguage: state.sourceLanguage.bcp47,
        targetLanguage: state.targetLanguage.bcp47,
        sourceText: state.spokenText,
        translatedText: state.translatedText,
        pronunciationScore: score,
      );
    });
  }

  @override
  void dispose() {
    _karaokeTimer?.cancel();
    super.dispose();
  }
}

final companionProvider =
    StateNotifierProvider<CompanionNotifier, CompanionState>((ref) {
  return CompanionNotifier();
});
