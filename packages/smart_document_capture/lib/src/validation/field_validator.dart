import '../text/text_normalizer.dart';

/// Outcome of a [FieldValidator].
class ValidationResult {
  /// The text is valid; [value] is its parsed form.
  const ValidationResult.valid(this.value)
      : isValid = true,
        message = null;

  /// The text is not valid, for the reason given in [message].
  const ValidationResult.invalid(String this.message)
      : isValid = false,
        value = null;

  /// Whether the text passed validation.
  final bool isValid;

  /// Parsed value, e.g. a `num` for amounts or a `JalaliDate` for dates.
  final Object? value;

  /// Why the text is invalid.
  final String? message;

  @override
  String toString() => isValid
      ? 'ValidationResult.valid($value)'
      : 'ValidationResult.invalid($message)';
}

/// Parses and checks the text found for a field.
///
/// Validators receive the raw OCR text; they normalize it themselves (see
/// [TextNormalizer]) so they also work on text typed by a user.
abstract interface class FieldValidator {
  /// Validates [raw] and returns the parsed value on success.
  ValidationResult validate(String raw);
}

/// Accepts any text that is not blank and has at least [minLength]
/// characters. The value is the trimmed, normalized text.
class TextValidator implements FieldValidator {
  /// Creates the validator.
  const TextValidator({this.minLength = 1, this.maxLength});

  /// Minimum number of characters.
  final int minLength;

  /// Maximum number of characters, if limited.
  final int? maxLength;

  @override
  ValidationResult validate(String raw) {
    final String text = TextNormalizer.normalize(raw);
    if (text.length < minLength) {
      return const ValidationResult.invalid('Text is too short.');
    }
    if (maxLength != null && text.length > maxLength!) {
      return const ValidationResult.invalid('Text is too long.');
    }
    return ValidationResult.valid(text);
  }
}

/// Accepts text matching [pattern] in full (after normalization).
class RegexValidator implements FieldValidator {
  /// Creates the validator.
  const RegexValidator(this.pattern, {this.message = 'Invalid format.'});

  /// Pattern the whole normalized text must match.
  final RegExp pattern;

  /// Message reported for text that does not match.
  final String message;

  @override
  ValidationResult validate(String raw) {
    final String text = TextNormalizer.normalize(raw);
    final RegExpMatch? m = pattern.firstMatch(text);
    if (m == null || m.start != 0 || m.end != text.length) {
      return ValidationResult.invalid(message);
    }
    return ValidationResult.valid(text);
  }
}

/// Accepts a number, with optional thousands separators and decimals.
/// The value is a `num`.
class NumberValidator implements FieldValidator {
  /// Creates the validator.
  const NumberValidator({this.min, this.max});

  /// Smallest accepted value.
  final num? min;

  /// Largest accepted value.
  final num? max;

  @override
  ValidationResult validate(String raw) {
    final num? n = parseNumber(raw);
    if (n == null) return const ValidationResult.invalid('Not a number.');
    if (min != null && n < min!) {
      return ValidationResult.invalid('Must be at least $min.');
    }
    if (max != null && n > max!) {
      return ValidationResult.invalid('Must be at most $max.');
    }
    return ValidationResult.valid(n);
  }

  /// Parses `1,250,000`, `۱٬۲۵۰٬۰۰۰`, `12.5` or `-3`; returns `null` for
  /// anything else.
  static num? parseNumber(String raw) {
    final String text = TextNormalizer.normalize(raw).replaceAll(' ', '');
    if (!RegExp(r'^-?(\d{1,3}(,\d{3})+|\d+)(\.\d+)?$').hasMatch(text)) {
      return null;
    }
    return num.tryParse(text.replaceAll(',', ''));
  }
}

/// Accepts a monetary amount such as `1,250,000 ریال` or `۸۵۰٬۰۰۰ تومان`.
///
/// The value is the number as a `num`; currency words are ignored, so keep
/// the unit consistent in your schema.
class AmountValidator implements FieldValidator {
  /// Creates the validator.
  const AmountValidator({this.allowZero = false});

  /// Whether `0` is a valid amount.
  final bool allowZero;

  static final RegExp _currency = RegExp(
      r'(ریال|تومان|تومن|rials?|tomans?|irr|irt|\$|usd|eur|€)',
      caseSensitive: false);

  @override
  ValidationResult validate(String raw) {
    final String text =
        TextNormalizer.normalize(raw).replaceAll(_currency, '').trim();
    final num? n = NumberValidator.parseNumber(text);
    if (n == null) return const ValidationResult.invalid('Not an amount.');
    if (n < 0 || (!allowZero && n == 0)) {
      return const ValidationResult.invalid('Amount must be positive.');
    }
    return ValidationResult.valid(n);
  }
}

/// Accepts a time of day such as `14:35` or `08:05:12`. The value is the
/// normalized `HH:mm` or `HH:mm:ss` text.
class TimeValidator implements FieldValidator {
  /// Creates the validator.
  const TimeValidator();

  @override
  ValidationResult validate(String raw) {
    final RegExpMatch? m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$')
        .firstMatch(TextNormalizer.normalize(raw).replaceAll(' ', ''));
    if (m == null) return const ValidationResult.invalid('Not a time.');
    final int h = int.parse(m[1]!);
    final int min = int.parse(m[2]!);
    final int? s = m[3] == null ? null : int.parse(m[3]!);
    if (h > 23 || min > 59 || (s != null && s > 59)) {
      return const ValidationResult.invalid('Not a time.');
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return ValidationResult.valid(s == null
        ? '${two(h)}:${two(min)}'
        : '${two(h)}:${two(min)}:${two(s)}');
  }
}
