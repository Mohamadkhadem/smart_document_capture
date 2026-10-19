import 'package:persian_calendar_kit/persian_calendar_kit.dart'
    show normalizePersianInput;

/// Text clean-up shared by locators and validators.
abstract final class TextNormalizer {
  /// Normalizes OCR output for parsing.
  ///
  /// Persian and Arabic digits become English digits, Arabic `ي`/`ك` become
  /// Persian `ی`/`ک`, tatweel and direction marks are removed, the Persian
  /// thousands (`٬`) and decimal (`٫`) separators become `,` and `.`, and
  /// runs of whitespace collapse into one space.
  static String normalize(String input) => normalizePersianInput(input)
      .replaceAll('٬', ',')
      .replaceAll('٫', '.')
      .replaceAll('،', ',');

  /// [normalize]d, lower-cased text without punctuation, for comparing
  /// labels and keywords.
  static String forMatching(String input) => normalize(input)
      .toLowerCase()
      .replaceAll(RegExp(r'[:：\-_.,،؛;()\[\]{}"«»]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Only the ASCII digits of [input], after [normalize].
  static String digitsOnly(String input) =>
      normalize(input).replaceAll(RegExp(r'[^0-9]'), '');
}
