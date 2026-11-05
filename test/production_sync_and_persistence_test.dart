import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/core/constants/character_data.dart';
import 'package:lingoboop/core/constants/language_data.dart';
import 'package:lingoboop/core/services/user_data_service.dart';
import 'package:lingoboop/features/companion/presentation/companion_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Production Character, Voice & Language Sync Tests', () {
    test('CharacterRegistry maps Panda, Fox, Cat, and Bunny canonically', () {
      final panda = CharacterRegistry.getByKey('panda');
      expect(panda.name, 'Pano');
      expect(panda.key, 'panda');
      expect(panda.accentColor.toARGB32(), equals(0xFF2C6E5E));

      final fox = CharacterRegistry.getByKey('fox');
      expect(fox.name, 'Maru');
      expect(fox.key, 'fox');
      expect(fox.accentColor.toARGB32(), equals(0xFFC4571C));

      final cat = CharacterRegistry.getByKey('cat');
      expect(cat.name, 'Mimi');
      expect(cat.key, 'cat');
      expect(cat.accentColor.toARGB32(), equals(0xFF6A4CC4));

      final bunny = CharacterRegistry.getByKey('bunny');
      expect(bunny.name, 'Bun');
      expect(bunny.key, 'bunny');
      expect(bunny.accentColor.toARGB32(), equals(0xFFC23D7B));
    });

    test('LanguageRegistry maps Gujarati, English, Spanish, Hindi dynamically', () {
      final gu = LanguageRegistry.getByCode('gu');
      final es = LanguageRegistry.getByCode('es');
      final en = LanguageRegistry.getByCode('en');
      final hi = LanguageRegistry.getByCode('hi');

      expect(gu.name, 'Gujarati');
      expect(gu.bcp47, 'gu-IN');

      expect(es.name, 'Spanish');
      expect(es.bcp47, 'es-ES');

      expect(en.name, 'English');
      expect(en.bcp47, 'en-US');

      expect(hi.name, contains('Hindi'));
      expect(hi.bcp47, 'hi-IN');
    });

    test('UserDataService caches and restores voice selection', () async {
      await UserDataService.instance.saveSelectedVoice('Devansh');
      final restoredVoice = await UserDataService.instance.getSelectedVoice();
      expect(restoredVoice, 'Devansh');

      await UserDataService.instance.saveSelectedVoice('Shivani');
      final restoredDefault = await UserDataService.instance.getSelectedVoice();
      expect(restoredDefault, 'Shivani');
    });

    test('UserDataService caches and restores character selection', () async {
      await UserDataService.instance.saveCachedCharacter('panda');
      final char = await UserDataService.instance.getCachedCharacter();
      expect(char, 'panda');

      await UserDataService.instance.saveCachedCharacter('cat');
      final char2 = await UserDataService.instance.getCachedCharacter();
      expect(char2, 'cat');
    });

    test('UserDataService caches and restores dynamic language codes', () async {
      await UserDataService.instance.saveCachedLanguages(
        sourceCode: 'gu',
        targetCode: 'es',
      );
      final langs = await UserDataService.instance.getCachedLanguages();
      expect(langs?['source'], 'gu');
      expect(langs?['target'], 'es');

      await UserDataService.instance.saveCachedLanguages(
        sourceCode: 'gu',
        targetCode: 'hi',
      );
      final langsHi = await UserDataService.instance.getCachedLanguages();
      expect(langsHi?['source'], 'gu');
      expect(langsHi?['target'], 'hi');
    });

    test('CompanionNotifier correctly cycles Panda, Fox, Cat and multiple language pairs', () async {
      final notifier = CompanionNotifier();
      
      // Panda test
      notifier.setPet('panda');
      expect(notifier.state.activePet.key, 'panda');
      expect(notifier.state.activePet.name, 'Pano');
      expect(notifier.state.activePet.accentColor.toARGB32(), equals(0xFF2C6E5E));

      // Gujarati -> Spanish
      notifier.setSourceLanguage('gu');
      notifier.setTargetLanguage('es');
      expect(notifier.state.sourceLanguage.code, 'gu');
      expect(notifier.state.sourceLanguage.name, 'Gujarati');
      expect(notifier.state.targetLanguage.code, 'es');
      expect(notifier.state.targetLanguage.name, 'Spanish');

      // Gujarati -> Hindi
      notifier.setTargetLanguage('hi');
      expect(notifier.state.targetLanguage.code, 'hi');
      expect(notifier.state.targetLanguage.name, contains('Hindi'));

      // Cat test
      notifier.setPet('cat');
      expect(notifier.state.activePet.key, 'cat');
      expect(notifier.state.activePet.name, 'Mimi');
      expect(notifier.state.activePet.accentColor.toARGB32(), equals(0xFF6A4CC4));

      // Voice selection
      notifier.setTtsVoice('Devansh');
      expect(notifier.state.selectedVoice, 'Devansh');

      notifier.dispose();
    });

    test('Conversation history pagination function signature defaults', () async {
      final conversations = await UserDataService.instance.getConversations();
      expect(conversations, isEmpty);

      final pagedConversations = await UserDataService.instance.getConversations(limit: 20, offset: 10);
      expect(pagedConversations, isEmpty);
    });
  });
}
