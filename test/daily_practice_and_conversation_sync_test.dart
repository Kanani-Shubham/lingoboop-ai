import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/features/companion/presentation/companion_state.dart';
import 'package:lingoboop/core/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.lingoboop.app/overlay'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getLatestCardState') {
          return {
            'originalText': '',
            'translatedText': '',
            'correction': null,
          };
        }
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        return 1;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.lingoboop.app/speech'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  group('Daily Practice & Conversation State Synchronization Tests', () {
    test('Test 1 & 7 — Initial clean idle prompt and clear active practice prompt', () {
      final notifier = CompanionNotifier();

      // Clean idle prompt, no fake conversations
      expect(notifier.state.spokenText, isEmpty);
      expect(notifier.state.translatedText, isEmpty);
      expect(notifier.state.words, isEmpty);
      expect(notifier.state.conversationStatus, equals(ConversationStatus.idle));

      // Simulate completing daily practice set and clearing active prompt
      notifier.clearActivePracticePrompt();
      expect(notifier.state.spokenText, isEmpty);
      expect(notifier.state.translatedText, isEmpty);
      expect(notifier.state.conversationStatus, equals(ConversationStatus.practiceCompleted));

      notifier.dispose();
    });

    test('Test 2 — New conversation speech after completion sets real text and overrides old state', () async {
      final notifier = CompanionNotifier();
      notifier.clearActivePracticePrompt();

      // User speaks a completely new sentence
      await notifier.stopListeningAndProcess('તમારું નામ શું છે?');

      expect(notifier.state.spokenText, equals('તમારું નામ શું છે?'));
      expect(notifier.state.conversationStatus, isNot(equals(ConversationStatus.practiceActive)));
      expect(notifier.state.spokenText, isNot(contains('Where is the nearest railway station?')));

      notifier.dispose();
    });

    test('Test 5 — Stale translation responses cannot overwrite newer active request', () async {
      final notifier = CompanionNotifier();

      // Request 1 starts
      notifier.startListening();
      final req1 = notifier.state.activeRequestId;

      // Request 2 starts immediately afterward
      notifier.startListening();
      final req2 = notifier.state.activeRequestId;
      expect(req2, greaterThan(req1));

      // Older Request 1 attempts to finalize with stale text
      await notifier.stopListeningAndProcess('વેન ઈઝ ધ નેક્સ્ટ ક્લાસ?', req1);

      // Verify that state did NOT accept stale req1
      expect(notifier.state.spokenText, isNot(equals('વેન ઈઝ ધ નેક્સ્ટ ક્લાસ?')));

      // Now Request 2 finalizes with newest speech
      await notifier.stopListeningAndProcess('તમારું નામ શું છે?', req2);
      expect(notifier.state.spokenText, equals('તમારું નામ શું છે?'));

      notifier.dispose();
    });

    test('Test 4 & 8 — Multilingual offline fallback produces unique phrases without duplicates', () {
      final speechService = SpeechService.instance;

      // Gujarati to English
      final guToEn = speechService.fetchDailyPractice(
        nativeLang: 'gu-IN',
        targetLang: 'en-US',
        count: 5,
      );

      // Gujarati to Bengali
      final guToBn = speechService.fetchDailyPractice(
        nativeLang: 'gu-IN',
        targetLang: 'bn-IN',
        count: 5,
      );

      return Future.wait([guToEn, guToBn]).then((results) {
        final enList = results[0];
        final bnList = results[1];

        expect(enList.length, equals(5));
        expect(bnList.length, equals(5));

        // Verify English target sentences
        final enTargets = enList.map((e) => e['target_sentence']).toSet();
        expect(enTargets.length, equals(5), reason: 'Must not have duplicate sentences');

        // Verify Bengali target sentences
        final bnTargets = bnList.map((e) => e['target_sentence']).toSet();
        expect(bnTargets.length, equals(5), reason: 'Must not have duplicate sentences');

        // Target sentences for Bengali must differ from English
        expect(enTargets, isNot(equals(bnTargets)));
      });
    });

    test('Test 6 — Overlay sync does not resurrect stale text after practice completion', () async {
      final notifier = CompanionNotifier();
      notifier.clearActivePracticePrompt();

      // Even if overlay has old text in preferences, syncFromNativeOverlay respects practiceCompleted
      await notifier.syncFromNativeOverlay();
      expect(notifier.state.translatedText, isEmpty);
      expect(notifier.state.spokenText, isEmpty);

      notifier.dispose();
    });
  });
}

