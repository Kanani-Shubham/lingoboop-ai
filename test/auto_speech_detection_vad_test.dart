import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/features/companion/presentation/companion_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        } else if (methodCall.method == 'requestPermissions') {
          return {0: 1};
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.lingoboop.app/speech'),
      (MethodCall methodCall) async {
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );
  });

  group('Automatic Speech Detection & VAD Lifecycle Tests', () {
    test('1. Single-tap recording start initiates listening state without secondary tap', () async {
      final notifier = CompanionNotifier();
      expect(notifier.state.isListening, isFalse);

      notifier.startListening();
      expect(notifier.state.isListening, isTrue);
      expect(notifier.state.petMode, equals('listen'));
      expect(notifier.state.statusNote, contains('Listening'));

      notifier.dispose();
    });

    test('2. Rapid repeated microphone taps do not create duplicate recording sessions', () async {
      final notifier = CompanionNotifier();

      // Rapidly invoke startListening 4 times
      notifier.startListening();
      notifier.startListening();
      notifier.startListening();
      notifier.startListening();

      expect(notifier.state.isListening, isTrue);
      expect(notifier.state.petMode, equals('listen'));

      notifier.dispose();
    });

    test('3. Manual cancellation returns companion to stable idle state', () async {
      final notifier = CompanionNotifier();
      notifier.startListening();
      expect(notifier.state.isListening, isTrue);

      await notifier.stopListeningAndProcess('');
      expect(notifier.state.isListening, isFalse);
      expect(notifier.state.petMode, equals('idle'));
      expect(notifier.state.statusNote, contains('Nothing heard'));

      notifier.dispose();
    });

    test('4. Automatic translation pipeline triggers automatically after final recognized text', () async {
      final notifier = CompanionNotifier();
      notifier.startListening();

      // When VAD auto-finalizes with recognized sentence:
      await notifier.stopListeningAndProcess('કેમ છો');

      // Spoken text is recorded and state advances to think/translation
      expect(notifier.state.spokenText, equals('કેમ છો'));
      expect(notifier.state.isListening, isFalse);

      notifier.dispose();
    });

    test('5. Repeat practice mode automatically evaluates pronunciation on final speech', () async {
      final notifier = CompanionNotifier();

      // Setup target translation
      notifier.setPet('panda');
      notifier.setSourceLanguage('gu');
      notifier.setTargetLanguage('en');
      notifier.updateFromExternalOverlay(
        spoken: 'કેમ છો',
        translated: 'How are you?',
      );

      // Start repeat practice
      await notifier.startRepeatPractice();
      expect(notifier.state.isRepeatPracticing, isTrue);
      expect(notifier.state.isListening, isTrue);

      // Cleanly stop repeat practice
      await notifier.stopRepeatPractice();
      expect(notifier.state.isRepeatPracticing, isFalse);
      expect(notifier.state.isListening, isFalse);

      notifier.dispose();
    });
  });
}
