import 'dart:math' as math;

enum WordAccuracyStatus {
  correct,
  partial,
  missed,
  extra,
}

class WordScoringResult {
  final String word;
  final WordAccuracyStatus status;
  final double similarity;
  final String? spokenAs;

  const WordScoringResult({
    required this.word,
    required this.status,
    this.similarity = 0.0,
    this.spokenAs,
  });
}

class PronunciationResult {
  final int matchPercentage;
  final bool hasSpoken;
  final String feedbackMessage;
  final List<WordScoringResult> wordResults;
  final List<String> matchedWords;
  final List<String> missedWords;
  final List<String> extraWords;

  const PronunciationResult({
    required this.matchPercentage,
    required this.hasSpoken,
    required this.feedbackMessage,
    required this.wordResults,
    required this.matchedWords,
    required this.missedWords,
    required this.extraWords,
  });
}

class PronunciationScorer {
  PronunciationScorer._();

  static final RegExp _punctRegex = RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?"।॥¿¡]');
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  /// Clean, lowercase, and tokenize a sentence into individual words
  static List<String> tokenize(String text) {
    if (text.trim().isEmpty) return const [];
    final clean = text
        .replaceAll(_punctRegex, ' ')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim()
        .toLowerCase();
    if (clean.isEmpty) return const [];
    return clean.split(' ').where((w) => w.isNotEmpty).toList();
  }

  /// Levenshtein edit distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1,
          math.min(v0[j + 1] + 1, v0[j] + cost),
        );
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  /// Character-level similarity ratio between 0.0 and 1.0
  static double wordSimilarity(String w1, String w2) {
    if (w1 == w2) return 1.0;
    final maxLen = math.max(w1.length, w2.length);
    if (maxLen == 0) return 1.0;
    final dist = levenshteinDistance(w1, w2);
    return ((maxLen - dist) / maxLen).clamp(0.0, 1.0);
  }

  /// Evaluate user spoken transcript against target expected sentence
  static PronunciationResult evaluate({
    required String expectedSentence,
    required String? spokenTranscript,
  }) {
    final expectedWords = tokenize(expectedSentence);
    final spokenWords = tokenize(spokenTranscript ?? '');

    // Case 1: Empty speech or uncaptured input
    if (spokenWords.isEmpty) {
      final missedResults = expectedWords
          .map((w) => WordScoringResult(word: w, status: WordAccuracyStatus.missed))
          .toList();

      return PronunciationResult(
        matchPercentage: 0,
        hasSpoken: false,
        feedbackMessage: 'Could not capture clear speech. Tap mic to try again.',
        wordResults: missedResults,
        matchedWords: const [],
        missedWords: List.from(expectedWords),
        extraWords: const [],
      );
    }

    if (expectedWords.isEmpty) {
      return const PronunciationResult(
        matchPercentage: 100,
        hasSpoken: true,
        feedbackMessage: 'Great job!',
        wordResults: [],
        matchedWords: [],
        missedWords: [],
        extraWords: [],
      );
    }

    // Dynamic Programming Matrix Alignment between expected and spoken word sequences
    final m = expectedWords.length;
    final n = spokenWords.length;

    // dp[i][j] stores the best cumulative similarity score
    final dp = List.generate(m + 1, (_) => List<double>.filled(n + 1, 0.0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final sim = wordSimilarity(expectedWords[i - 1], spokenWords[j - 1]);
        final matchScore = dp[i - 1][j - 1] + (sim >= 0.65 ? sim : 0.0);
        dp[i][j] = math.max(matchScore, math.max(dp[i - 1][j], dp[i][j - 1]));
      }
    }

    // Backtrack to build aligned word-level results
    int i = m;
    int j = n;
    final alignedExpected = <WordScoringResult>[];
    final matched = <String>[];
    final missed = <String>[];
    final extra = <String>[];

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final sim = wordSimilarity(expectedWords[i - 1], spokenWords[j - 1]);
        if (sim >= 0.65 && (dp[i][j] - (dp[i - 1][j - 1] + sim)).abs() < 1e-4) {
          final isExact = sim >= 0.85;
          final status = isExact ? WordAccuracyStatus.correct : WordAccuracyStatus.partial;
          alignedExpected.add(WordScoringResult(
            word: expectedWords[i - 1],
            status: status,
            similarity: sim,
            spokenAs: spokenWords[j - 1],
          ));
          matched.add(expectedWords[i - 1]);
          i--;
          j--;
          continue;
        }
      }

      if (i > 0 && (j == 0 || dp[i][j] == dp[i - 1][j])) {
        alignedExpected.add(WordScoringResult(
          word: expectedWords[i - 1],
          status: WordAccuracyStatus.missed,
          similarity: 0.0,
        ));
        missed.add(expectedWords[i - 1]);
        i--;
      } else if (j > 0) {
        extra.add(spokenWords[j - 1]);
        j--;
      }
    }

    // Aligned results were gathered in reverse order
    final orderedResults = alignedExpected.reversed.toList();

    // Match percentage based on expected words matched with weighted partial credit
    double earnedScore = 0.0;
    for (final res in orderedResults) {
      if (res.status == WordAccuracyStatus.correct) {
        earnedScore += 1.0;
      } else if (res.status == WordAccuracyStatus.partial) {
        earnedScore += res.similarity.clamp(0.5, 0.85);
      }
    }

    final pct = ((earnedScore / expectedWords.length) * 100.0).round().clamp(0, 100);

    String feedback;
    if (pct >= 85) {
      feedback = 'Excellent pronunciation! Perfect flow. ($pct%)';
    } else if (pct >= 70) {
      feedback = 'Great job! ($pct% matched). Practice highlighted words.';
    } else if (pct >= 40) {
      feedback = '$pct% matched. Check missed words and try again.';
    } else {
      feedback = 'Keep practicing! ($pct% matched). Tap Slow to hear each word.';
    }

    return PronunciationResult(
      matchPercentage: pct,
      hasSpoken: true,
      feedbackMessage: feedback,
      wordResults: orderedResults,
      matchedWords: matched,
      missedWords: missed,
      extraWords: extra,
    );
  }
}

