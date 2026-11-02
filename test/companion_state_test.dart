import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/core/constants/app_colors.dart';
import 'package:lingoboop/features/companion/presentation/companion_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanionNotifier Riverpod State Management Tests', () {
    late CompanionNotifier notifier;

    setUp(() {
      notifier = CompanionNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('Initial state defaults to Maru (Fox), Gujarati to English', () {
      final state = notifier.state;
      expect(state.activePet.name, 'Maru');
      expect(state.activePet.accentColor, AppColors.foxMaru);
      expect(state.sourceLanguage.code, 'gu');
      expect(state.targetLanguage.code, 'en');
      expect(state.isCardOpen, isFalse);
      expect(state.isListening, isFalse);
    });

    test('Switching pet updates activePet and dynamic theme accent', () {
      notifier.setPet('cat');
      expect(notifier.state.activePet.name, 'Mimi');
      expect(notifier.state.activePet.accentColor, AppColors.catMimi);

      notifier.setPet('panda');
      expect(notifier.state.activePet.name, 'Pano');
      expect(notifier.state.activePet.accentColor, AppColors.pandaPano);
    });

    test('Switching languages updates state correctly', () {
      notifier.setSourceLanguage('hi');
      expect(notifier.state.sourceLanguage.code, 'hi');
      expect(notifier.state.sourceLanguage.name, 'Hindi / Hinglish');

      notifier.setTargetLanguage('es');
      expect(notifier.state.targetLanguage.code, 'es');
      expect(notifier.state.targetLanguage.name, 'Spanish');
    });

    test('Toggle card changes isCardOpen and pet mode', () {
      notifier.toggleCard();
      expect(notifier.state.isCardOpen, isTrue);
      expect(notifier.state.petMode, 'talk');

      notifier.toggleCard();
      expect(notifier.state.isCardOpen, isFalse);
      expect(notifier.state.petMode, 'idle');
    });

    test('Setting petMode explicitly updates state across prototype animation modes', () {
      const modes = ['walk', 'dance', 'think', 'talk', 'listen', 'drag', 'oops', 'cheer'];
      for (final m in modes) {
        notifier.setPetMode(m);
        expect(notifier.state.petMode, m);
      }
    });

    test('Submitting typed sentence triggers translation and populates karaoke words', () async {
      notifier.submitTypedText('Train to Surat');
      expect(notifier.state.spokenText, 'Train to Surat');
      expect(notifier.state.petMode, 'think');

      // Allow simulated async translation delay
      await Future.delayed(const Duration(milliseconds: 700));

      expect(notifier.state.translatedText, contains('Surat'));
      expect(notifier.state.words.isNotEmpty, isTrue);
      expect(notifier.state.petMode, 'talk');
    });
  });
}

