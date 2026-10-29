/// ISO 639-1 codes matching what deep-translator (the worker's
/// translation library) accepts. Keep this list in sync if you add more
/// on the Python side.
class Language {
  final String code;
  final String label;
  const Language(this.code, this.label);
}

const supportedLanguages = [
  Language('es', 'Spanish'),
  Language('fr', 'French'),
  Language('de', 'German'),
  Language('hi', 'Hindi'),
  Language('ja', 'Japanese'),
  Language('zh-CN', 'Chinese (Simplified)'),
  Language('ar', 'Arabic'),
  Language('pt', 'Portuguese'),
  Language('ru', 'Russian'),
  Language('ko', 'Korean'),
];

String languageLabelFor(String? code) {
  if (code == null) return 'None';
  return supportedLanguages
      .firstWhere((l) => l.code == code, orElse: () => Language(code, code))
      .label;
}
