import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/character_data.dart';
import '../../../core/constants/language_data.dart';
import '../../../core/services/overlay_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/user_data_service.dart';
import '../../../core/widgets/karaoke_lyrics_view.dart';

class CompanionState {
  final CharacterModel activePet;
  final LanguageItem sourceLanguage;
  final LanguageItem targetLanguage;
  final bool isCardOpen;
  final bool isSettingsOpen;
  final bool isListening;
  final bool isRepeatPracticing;
  final bool isEditingTranscript;
  final String spokenText;
  final String translatedText;
  final String? aiReplyText;
  final String? correction;
  final String? explanation;
  final List<String> examples;
  final String? pronunciationGuide;
  final String statusNote;
  final List<KaraokeWord> words;
  final int highlightedIndex;
  final Offset petPosition;
  final String petMode; // 'idle', 'walk', 'dance', 'think', 'talk', 'listen', 'drag', 'oops'
  final String? lastTtsPath;
  final String aiProvider;
  final List<Map<String, String>> conversationHistory;

  const CompanionState({
    required this.activePet,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isCardOpen = false,
    this.isSettingsOpen = false,
    this.isListening = false,
    this.isRepeatPracticing = false,
    this.isEditingTranscript = false,
    this.spokenText = '',
    this.translatedText = '',
    this.aiReplyText,
    this.correction,
    this.explanation,
    this.examples = const [],
    this.pronunciationGuide,
    this.statusNote = 'Tap the mic and speak.',
    this.words = const [],
    this.highlightedIndex = -1,
    this.petPosition = const Offset(110, 260),
    this.petMode = 'idle',
    this.lastTtsPath,
    this.aiProvider = 'groq',
    this.conversationHistory = const [],
  });

  CompanionState copyWith({
    CharacterModel? activePet,
    LanguageItem? sourceLanguage,
    LanguageItem? targetLanguage,
    bool? isCardOpen,
    bool? isSettingsOpen,
    bool? isListening,
    bool? isRepeatPracticing,
    bool? isEditingTranscript,
    String? spokenText,
    String? translatedText,
    String? aiReplyText,
    String? correction,
    String? explanation,
    List<String>? examples,
    String? pronunciationGuide,
    String? statusNote,
    List<KaraokeWord>? words,
    int? highlightedIndex,
    Offset? petPosition,
    String? petMode,
    String? lastTtsPath,
    String? aiProvider,
    List<Map<String, String>>? conversationHistory,
  }) {
    return CompanionState(
      activePet: activePet ?? this.activePet,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      isCardOpen: isCardOpen ?? this.isCardOpen,
      isSettingsOpen: isSettingsOpen ?? this.isSettingsOpen,
      isListening: isListening ?? this.isListening,
      isRepeatPracticing: isRepeatPracticing ?? this.isRepeatPracticing,
      isEditingTranscript: isEditingTranscript ?? this.isEditingTranscript,
      spokenText: spokenText ?? this.spokenText,
      translatedText: translatedText ?? this.translatedText,
      aiReplyText: aiReplyText ?? this.aiReplyText,
      correction: correction ?? this.correction,
      explanation: explanation ?? this.explanation,
      examples: examples ?? this.examples,
      pronunciationGuide: pronunciationGuide ?? this.pronunciationGuide,
      statusNote: statusNote ?? this.statusNote,
      words: words ?? this.words,
      highlightedIndex: highlightedIndex ?? this.highlightedIndex,
      petPosition: petPosition ?? this.petPosition,
      petMode: petMode ?? this.petMode,
      lastTtsPath: lastTtsPath ?? this.lastTtsPath,
      aiProvider: aiProvider ?? this.aiProvider,
      conversationHistory: conversationHistory ?? this.conversationHistory,
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
        ) {
    SpeechService.instance.resolveBackendUrl();
  }

  Timer? _karaokeTimer;

  void setPet(String petKey) {
    final pet = CharacterRegistry.getByKey(petKey);
    state = state.copyWith(activePet: pet);
    UserDataService.instance.savePreferences(activeCharacterId: petKey);
    final colorHex = '#${pet.accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    OverlayService.instance.updatePet(
      petKey: pet.key,
      petName: pet.name,
      petColorHex: colorHex,
    );
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
    OverlayService.instance.updateLanguages(
      sourceLang: lang.bcp47,
      targetLang: state.targetLanguage.bcp47,
    );
  }

  void setTargetLanguage(String code) {
    final lang = LanguageRegistry.getByCode(code);
    state = state.copyWith(targetLanguage: lang);
    UserDataService.instance.saveUserLanguage(
      nativeCode: state.sourceLanguage.code,
      targetCode: code,
    );
    OverlayService.instance.updateLanguages(
      sourceLang: state.sourceLanguage.bcp47,
      targetLang: lang.bcp47,
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
    SpeechService.instance.stopPlayback();
    state = state.copyWith(
      isCardOpen: false,
      isListening: false,
      isRepeatPracticing: false,
      isEditingTranscript: false,
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

  void setPetMode(String mode) {
    state = state.copyWith(petMode: mode);
  }

  void setEditingTranscript(bool editing) {
    state = state.copyWith(isEditingTranscript: editing);
  }

  void updateSpokenText(String text) {
    state = state.copyWith(spokenText: text);
  }

  /// Start recording real speech via microphone
  Future<void> startListening() async {
    _karaokeTimer?.cancel();
    await SpeechService.instance.stopPlayback();

    final started = await SpeechService.instance.startRecording();
    if (!started) {
      final isPermDenied = await Permission.microphone.isPermanentlyDenied;
      state = state.copyWith(
        isListening: false,
        petMode: 'oops',
        statusNote: isPermDenied
            ? 'Microphone blocked in Settings. Tap to allow.'
            : 'Microphone permission needed. Please allow mic access.',
      );
      if (isPermDenied) {
        await openAppSettings();
      }
      return;
    }

    state = state.copyWith(
      isListening: true,
      isRepeatPracticing: false,
      isEditingTranscript: false,
      petMode: 'listen',
      statusNote: 'Listening… speak in ${state.sourceLanguage.name}',
    );
  }

  /// Stop microphone recording and process STT -> Groq AI -> Timbre TTS pipeline
  Future<void> stopListeningAndProcess([String? directText]) async {
    if (!state.isListening && directText == null) return;

    state = state.copyWith(
      isListening: false,
      petMode: 'think',
      statusNote: 'Transcribing speech via Prisma STT…',
    );

    String? recognizedText = directText;

    if (recognizedText == null || recognizedText.isEmpty) {
      final audioPath = await SpeechService.instance.stopRecording();
      if (audioPath != null) {
        recognizedText = await SpeechService.instance.transcribeAudio(
          audioPath: audioPath,
          languageCode: state.sourceLanguage.bcp47,
        );
      }
    }

    if (recognizedText == null || recognizedText.trim().isEmpty) {
      state = state.copyWith(
        petMode: 'idle',
        statusNote: 'Could not capture clear speech. Tap mic to try again.',
      );
      return;
    }

    state = state.copyWith(
      spokenText: recognizedText,
      petMode: 'think',
      statusNote: 'Reasoning with Groq GPT-OSS 120B…',
    );

    await _processWithGroqAITutor(recognizedText);
  }

  /// Submit typed sentence (Text-only mode)
  Future<void> submitTypedText(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(
      spokenText: text.trim(),
      petMode: 'think',
      statusNote: 'Reasoning with Groq GPT-OSS 120B…',
    );
    await _processWithGroqAITutor(text.trim());
  }

  /// Central Groq AI tutor reasoning pipeline
  Future<void> _processWithGroqAITutor(String input) async {
    // 1. Call Groq AI Tutor
    final aiResult = await SpeechService.instance.askAITutor(
      userMessage: input,
      nativeLang: state.sourceLanguage.bcp47,
      targetLang: state.targetLanguage.bcp47,
      characterId: state.activePet.key,
      history: state.conversationHistory,
      mode: 'tutor',
    );

    String translated = input;
    String? replyText;
    String? correction;
    String? explanation;
    List<String> examples = [];
    String? pronunciationGuide;
    String providerName = 'groq';

    if (aiResult != null) {
      translated = (aiResult['translated_text'] as String?)?.trim() ?? input;
      replyText = aiResult['reply_text'] as String?;
      correction = aiResult['correction'] as String?;
      explanation = aiResult['explanation'] as String?;
      examples = (aiResult['examples'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      pronunciationGuide = aiResult['pronunciation_guide'] as String?;
      providerName = (aiResult['provider'] as String?) ?? 'groq';
    } else {
      // Graceful offline fallback
      final fallbackTrans = await SpeechService.instance.translateText(
        text: input,
        sourceLang: state.sourceLanguage.bcp47,
        targetLang: state.targetLanguage.bcp47,
        characterId: state.activePet.key,
      );
      translated = (fallbackTrans?['translated_text'] as String?)?.trim() ?? input;
      providerName = 'local_fallback';
    }

    // Tokenize translated sentence for karaoke word view
    final rawWords = translated.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordList = rawWords
        .map((w) => KaraokeWord(text: w, isHighlighted: false, evaluation: WordEvaluationState.none))
        .toList();

    // Update bounded conversation history
    final updatedHistory = List<Map<String, String>>.from(state.conversationHistory);
    updatedHistory.add({'role': 'user', 'content': input});
    if (replyText != null && replyText.isNotEmpty) {
      updatedHistory.add({'role': 'assistant', 'content': replyText});
    }
    final boundedHistory = updatedHistory.length > 8 ? updatedHistory.sublist(updatedHistory.length - 8) : updatedHistory;

    state = state.copyWith(
      translatedText: translated,
      aiReplyText: replyText,
      correction: correction,
      explanation: explanation,
      examples: examples,
      pronunciationGuide: pronunciationGuide,
      words: wordList,
      aiProvider: providerName,
      conversationHistory: boundedHistory,
      statusNote: 'Synthesizing voice via Gnani Timbre TTS…',
      petMode: 'think',
    );

    // Save to real database
    UserDataService.instance.recordConversationMessage(
      characterId: state.activePet.key,
      sourceLanguage: state.sourceLanguage.bcp47,
      targetLanguage: state.targetLanguage.bcp47,
      sourceText: input,
      translatedText: translated,
    );

    // Synthesize real TTS audio with Gnani Timbre
    final textToSpeak = translated.isNotEmpty ? translated : (replyText ?? input);
    final ttsPath = await SpeechService.instance.synthesizeTTS(
      text: textToSpeak,
      languageCode: state.targetLanguage.bcp47,
      speed: 1.0,
    );

    state = state.copyWith(
      lastTtsPath: ttsPath,
      petMode: 'talk',
      statusNote: '',
    );

    playKaraoke(1.0);
  }

  /// Play audio with karaoke highlighting (1.0x or 0.7x)
  void playKaraoke(double rate) {
    _karaokeTimer?.cancel();
    if (state.words.isEmpty) return;

    // Play synthesized audio file if available
    if (state.lastTtsPath != null) {
      SpeechService.instance.playAudioFile(state.lastTtsPath!, speed: rate);
    } else {
      final textToSpeak = state.translatedText.isNotEmpty ? state.translatedText : state.spokenText;
      if (textToSpeak.isNotEmpty) {
        SpeechService.instance.synthesizeTTS(
          text: textToSpeak,
          languageCode: state.targetLanguage.bcp47,
          speed: rate,
        ).then((path) {
          if (path != null) {
            state = state.copyWith(lastTtsPath: path);
            SpeechService.instance.playAudioFile(path, speed: rate);
          }
        });
      }
    }

    // Reset highlighting
    final resetWords = state.words
        .map((w) => w.copyWith(isHighlighted: false, evaluation: WordEvaluationState.none))
        .toList();
    state = state.copyWith(words: resetWords, petMode: 'talk');

    int index = 0;
    final intervalMs = (420 / rate).round();

    _karaokeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (index >= state.words.length) {
        timer.cancel();
        state = state.copyWith(
          petMode: 'dance',
          statusNote: 'Tap Repeat to test your pronunciation!',
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

  /// Start repeat-after-me pronunciation practice
  Future<void> startRepeatPractice() async {
    if (state.words.isEmpty) {
      state = state.copyWith(statusNote: 'Say or type something first, then repeat it.');
      return;
    }

    _karaokeTimer?.cancel();
    await SpeechService.instance.stopPlayback();

    final started = await SpeechService.instance.startRecording();
    if (!started) {
      state = state.copyWith(
        isListening: false,
        petMode: 'oops',
        statusNote: 'Microphone permission needed for repeat practice.',
      );
      return;
    }

    state = state.copyWith(
      statusNote: 'Say the target sentence out loud now…',
      isListening: true,
      isRepeatPracticing: true,
      petMode: 'listen',
    );
  }

  /// Stop repeat practice and evaluate honest token-level matching
  Future<void> stopRepeatPractice() async {
    if (!state.isRepeatPracticing) return;

    state = state.copyWith(
      isListening: false,
      isRepeatPracticing: false,
      petMode: 'think',
      statusNote: 'Analyzing pronunciation…',
    );

    final audioPath = await SpeechService.instance.stopRecording();
    String userSpoken = '';

    if (audioPath != null) {
      final transcript = await SpeechService.instance.transcribeAudio(
        audioPath: audioPath,
        languageCode: state.targetLanguage.bcp47,
      );
      userSpoken = transcript ?? '';
    }

    // Tokenize user words for genuine comparison
    final userTokens = userSpoken
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\w]'), ''))
        .where((w) => w.isNotEmpty)
        .toSet();

    // Evaluate each target word honestly
    int matchedCount = 0;
    final evaluatedWords = state.words.map((w) {
      final cleanTarget = w.text.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final isMatched = userTokens.contains(cleanTarget);
      if (isMatched) matchedCount++;
      return w.copyWith(
        isHighlighted: true,
        evaluation: isMatched ? WordEvaluationState.ok : WordEvaluationState.miss,
      );
    }).toList();

    final total = evaluatedWords.isEmpty ? 1 : evaluatedWords.length;
    final score = (matchedCount / total) * 100.0;
    final allOk = score >= 80.0;

    state = state.copyWith(
      words: evaluatedWords,
      statusNote: allOk
          ? 'Excellent! ${score.toInt()}% matched.'
          : '${score.toInt()}% matched. Check missed words and try again.',
      petMode: allOk ? 'dance' : 'oops',
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
  }

  @override
  void dispose() {
    _karaokeTimer?.cancel();
    SpeechService.instance.stopPlayback();
    super.dispose();
  }
}

final companionProvider =
    StateNotifierProvider<CompanionNotifier, CompanionState>((ref) {
  return CompanionNotifier();
});
