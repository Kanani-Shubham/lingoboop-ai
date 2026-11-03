import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/core/utils/pronunciation_scorer.dart';

void main() {
  group('PronunciationScorer Tests', () {
    test('Empty or null user speech returns hasSpoken=false without penalizing', () {
      final res = PronunciationScorer.evaluate(
        expectedSentence: 'My name is, and I am learning English.',
        spokenTranscript: '',
      );

      expect(res.hasSpoken, false);
      expect(res.matchPercentage, 0);
      expect(res.feedbackMessage, contains('Could not capture clear speech'));
      expect(res.wordResults.every((w) => w.status == WordAccuracyStatus.missed), true);
    });

    test('Exact match returns 100% and correct status for all words', () {
      final res = PronunciationScorer.evaluate(
        expectedSentence: 'Where is the nearest railway station?',
        spokenTranscript: 'where is the nearest railway station',
      );

      expect(res.hasSpoken, true);
      expect(res.matchPercentage, 100);
      expect(res.feedbackMessage, contains('Excellent pronunciation'));
      expect(res.matchedWords.length, 6);
      expect(res.missedWords.isEmpty, true);
    });

    test('Partial match with minor mispronunciation gives weighted credit', () {
      final res = PronunciationScorer.evaluate(
        expectedSentence: 'I am learning English today',
        spokenTranscript: 'I am learnin English today',
      );

      expect(res.hasSpoken, true);
      expect(res.matchPercentage, greaterThanOrEqualTo(85));
      expect(res.matchedWords.contains('learning'), true);
    });

    test('Punctuation and casing differences are normalized cleanly', () {
      final res = PronunciationScorer.evaluate(
        expectedSentence: 'Hello! How are you, Shubham?',
        spokenTranscript: 'hello how are you shubham',
      );

      expect(res.hasSpoken, true);
      expect(res.matchPercentage, 100);
    });

    test('Gujarati script matching works accurately', () {
      final res = PronunciationScorer.evaluate(
        expectedSentence: 'મારું નામ શુભમ છે',
        spokenTranscript: 'મારું નામ શુભમ છે',
      );

      expect(res.hasSpoken, true);
      expect(res.matchPercentage, 100);
      expect(res.matchedWords.length, 4);
    });
  });
}

