/// Regular expressions for common values, written for normalized text
/// (English digits, Persian letters).
abstract final class ValuePatterns {
  /// Dates such as `1404/07/27`, `04-7-27` or `27.07.1404`.
  static final RegExp date =
      RegExp(r'\d{2,4}\s*[/\-.]\s*\d{1,2}\s*[/\-.]\s*\d{1,4}');

  /// Times such as `14:35` or `08:05:12`.
  static final RegExp time = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');

  /// Amounts such as `1,250,000`, `850000 ریال` or `12.50`.
  static final RegExp amount = RegExp(
      r'\d{1,3}(?:,\d{3})+(?:\.\d+)?(?:\s*(?:ریال|تومان))?|\d+(?:\.\d+)?(?:\s*(?:ریال|تومان))?');

  /// Card numbers, plain or masked: `6037-9912-3456-7890`,
  /// `603799******1234`.
  static final RegExp cardNumber = RegExp(
      r'[\d*xX]{4}[\s\-]?[\d*xX]{2,4}[\s\-]?[\d*xX]{2,4}[\s\-]?[\d*xX]{4}');

  /// Iranian IBAN with or without the `IR` prefix and separators.
  static final RegExp sheba = RegExp(r'(?:IR|ir)?\s?\d{2}(?:[\s\-]?\d){22}');

  /// Iranian mobile numbers.
  static final RegExp mobile =
      RegExp(r'(?:\+98|0098|0)?9\d{2}[\s\-]?\d{3}[\s\-]?\d{4}');

  /// Ten-digit national codes, optionally with dashes: `001-234567-8`.
  static final RegExp nationalCode = RegExp(r'\b\d{3}-?\d{6}-?\d\b');

  /// Reference / tracking numbers: four or more digits.
  static final RegExp reference = RegExp(r'\d{4,}');
}
