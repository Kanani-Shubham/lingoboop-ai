class LanguageItem {
  final String code;
  final String name;
  final String bcp47;
  final String flag;

  const LanguageItem({
    required this.code,
    required this.name,
    required this.bcp47,
    required this.flag,
  });
}

class LanguageRegistry {
  LanguageRegistry._();

  static const List<LanguageItem> languages = [
    LanguageItem(code: 'gu', name: 'Gujarati', bcp47: 'gu-IN', flag: '🇮🇳'),
    LanguageItem(code: 'hi', name: 'Hindi / Hinglish', bcp47: 'hi-IN', flag: '🇮🇳'),
    LanguageItem(code: 'en', name: 'English', bcp47: 'en-US', flag: '🇺🇸'),
    LanguageItem(code: 'ta', name: 'Tamil', bcp47: 'ta-IN', flag: '🇮🇳'),
    LanguageItem(code: 'te', name: 'Telugu', bcp47: 'te-IN', flag: '🇮🇳'),
    LanguageItem(code: 'mr', name: 'Marathi', bcp47: 'mr-IN', flag: '🇮🇳'),
    LanguageItem(code: 'bn', name: 'Bengali', bcp47: 'bn-IN', flag: '🇮🇳'),
    LanguageItem(code: 'es', name: 'Spanish', bcp47: 'es-ES', flag: '🇪🇸'),
    LanguageItem(code: 'fr', name: 'French', bcp47: 'fr-FR', flag: '🇫🇷'),
    LanguageItem(code: 'ja', name: 'Japanese', bcp47: 'ja-JP', flag: '🇯🇵'),
  ];

  static LanguageItem getByCode(String code) {
    return languages.firstWhere(
      (l) => l.code == code,
      orElse: () => languages.first,
    );
  }
}

