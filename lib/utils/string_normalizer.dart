class StringNormalizer {
  /// Removes Arabic diacritics (Tashkeel) and normalizes Alef variants.
  static String normalizeArabic(String input) {
    if (input.isEmpty) return '';

    String normalized = input;

    // Strip Tashkeel (vowels/diacritics)
    final RegExp tashkeelRegex = RegExp(r'[\u064B-\u0652\u0670]');
    normalized = normalized.replaceAll(tashkeelRegex, '');

    // Normalize Alef variants (أ, إ, آ -> ا)
    normalized = normalized.replaceAll(RegExp(r'[\u0622\u0623\u0625]'), '\u0627');

    // Normalize Taa Marbuta (ة -> ه)
    normalized = normalized.replaceAll('\u0629', '\u0647');

    // Normalize Alif Maqsura (ى -> ي)
    normalized = normalized.replaceAll('\u0649', '\u064A');

    return normalized.trim().toLowerCase();
  }

  /// Normalizes generic text (English/Arabic) for matching.
  static String normalize(String input) {
    String clean = normalizeArabic(input);
    return clean.toLowerCase().trim();
  }
}