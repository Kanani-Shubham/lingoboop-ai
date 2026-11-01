import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/character_data.dart';
import '../../../core/constants/language_data.dart';
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
  final String petMode; // 'idle', 'walk', 'dance', 'think', 'talk', 'listen', 'drag'

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
    this.petPosition = const Offset(120, 480),
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
  }

  void setSourceLanguage(String code) {
    final lang = LanguageRegistry.getByCode(code);
    state = state.copyWith(
      sourceLanguage: lang,
      statusNote: 'Tap the mic and speak ${lang.name}.',
    );
  }

  void setTargetLanguage(String code) {
    final lang = LanguageRegistry.getByCode(code);
    state = state.copyWith(targetLanguage: lang);
  }

  void toggleCard() {
    final willOpen = !state.isCardOpen;
    state = state.copyWith(
      isCardOpen: willOpen,
      isSettingsOpen: false,
      petMode: willOpen ? 'talk' : 'idle',
      statusNote: willOpen
          ? (state.translatedText.isEmpty
              ? 'Tap the mic and speak ${state.sourceLanguage.name}.'
              : state.statusNote)
          : state.statusNote,
    );
  }

  void openCard() {
    state = state.copyWith(
      isCardOpen: true,
      isSettingsOpen: false,
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
    state = state.copyWith(
      isSettingsOpen: !state.isSettingsOpen,
      isCardOpen: false,
    );
  }

  void closeSettings() {
    state = state.copyWith(isSettingsOpen: false);
  }

  void updatePetPosition(Offset newPos) {
    state = state.copyWith(petPosition: newPos, petMode: 'drag');
  }

  void finishPetDrag() {
    state = state.copyWith(petMode: 'idle');
  }

  void startListening() {
    _karaokeTimer?.cancel();
    state = state.copyWith(
      isListening: true,
      petMode: 'listen',
      statusNote: 'Listening…',
      spokenText: '',
      translatedText: '',
      words: [],
    );
  }

  void stopListeningAndProcess(String userSpeech) {
    state = state.copyWith(
      isListening: false,
      spokenText: userSpeech,
      petMode: 'think',
      statusNote: 'Translating…',
    );

    // Realistic demonstration data based on HTML prototype
    Future.delayed(const Duration(milliseconds: 600), () {
      _demonstrateTranslation(userSpeech);
    });
  }

  void submitTypedText(String text) {
    if (text.trim().isEmpty) return;
    state = state.copyWith(
      spokenText: text,
      petMode: 'think',
      statusNote: 'Translating…',
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      _demonstrateTranslation(text);
    });
  }

  void _demonstrateTranslation(String input) {
    // Standard phrase dictionary from HTML prototype
    String translated = "I am practicing every day.";
    if (input.toLowerCase().contains("train") || input.contains("સુરત") || input.contains("ट्रेन")) {
      translated = "The train to Surat leaves at platform three.";
    } else if (input.toLowerCase().contains("dad") || input.contains("પપ્પા") || input.contains("पापा")) {
      translated = "Let us call Dad about Sunday lunch.";
    } else if (input.toLowerCase().contains("rice") || input.contains("ચોખા") || input.contains("चावल")) {
      translated = "Buy rice, ghee, mangoes, and two lemons.";
    } else {
      translated = "Practice speaking out loud, even if it feels difficult.";
    }

    final rawWords = translated.split(' ');
    final wordList = rawWords
        .map((w) => KaraokeWord(text: w, isHighlighted: false))
        .toList();

    state = state.copyWith(
      translatedText: translated,
      words: wordList,
      statusNote: '',
      petMode: 'talk',
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
    final intervalMs = (400 / rate).round();

    _karaokeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (index >= state.words.length) {
        timer.cancel();
        state = state.copyWith(
          petMode: 'dance',
          statusNote: 'Completed! Tap Repeat to practice.',
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
      statusNote: 'Say the English sentence out loud…',
      isListening: true,
      petMode: 'listen',
    );

    Future.delayed(const Duration(seconds: 2), () {
      // Simulate speech match scoring
      final evaluatedWords = state.words.map((w) {
        // Mark first 80% as ok, last as potential miss for demonstration
        final isOk = state.words.indexOf(w) < (state.words.length * 0.75);
        return w.copyWith(
          isHighlighted: true,
          evaluation: isOk ? WordEvaluationState.ok : WordEvaluationState.miss,
        );
      }).toList();

      final allOk = evaluatedWords.every((w) => w.evaluation == WordEvaluationState.ok);
      state = state.copyWith(
        isListening: false,
        words: evaluatedWords,
        statusNote: allOk
            ? 'All words matched. Nicely done!'
            : 'Good attempt! Try the underlined words again.',
        petMode: allOk ? 'dance' : 'oops',
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
