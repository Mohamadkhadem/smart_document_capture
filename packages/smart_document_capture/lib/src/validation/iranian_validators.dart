import 'package:persian_calendar_kit/persian_calendar_kit.dart';

import '../text/text_normalizer.dart';
import 'field_validator.dart';

/// Iranian national code (کد ملی): 10 digits with a check digit.
///
/// Codes with 8 or 9 digits are padded with leading zeros, as on older cards.
/// The value is the 10-digit code.
class NationalCodeValidator implements FieldValidator {
  /// Creates the validator.
  const NationalCodeValidator();

  @override
  ValidationResult validate(String raw) {
    final String digits = TextNormalizer.digitsOnly(raw);
    if (digits.length < 8 || digits.length > 10) {
      return const ValidationResult.invalid(
          'National code must have 10 digits.');
    }
    final String code = digits.padLeft(10, '0');
    return isValid(code)
        ? ValidationResult.valid(code)
        : const ValidationResult.invalid('Invalid national code checksum.');
  }

  /// Whether the 10-digit [code] has a correct check digit.
  static bool isValid(String code) {
    if (!RegExp(r'^\d{10}$').hasMatch(code)) return false;
    if (RegExp(r'^(\d)\1{9}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(code[i]) * (10 - i);
    }
    final int r = sum % 11;
    final int check = int.parse(code[9]);
    return r < 2 ? check == r : check == 11 - r;
  }
}

/// Bank card number (شماره کارت): 16 digits passing the Luhn check.
///
/// Receipts usually print masked numbers such as `6037-99**-****-1234`; set
/// [allowMasked] to accept them. The value is the 16 digits, with `*` for
/// masked ones.
class BankCardValidator implements FieldValidator {
  /// Creates the validator.
  const BankCardValidator({this.allowMasked = false});

  /// Whether partly masked numbers are accepted (without a Luhn check).
  final bool allowMasked;

  @override
  ValidationResult validate(String raw) {
    final String text = TextNormalizer.normalize(raw)
        .replaceAll(RegExp(r'[\s\-]'), '')
        .replaceAll(RegExp(r'[xX×]'), '*');
    if (RegExp(r'^\d{16}$').hasMatch(text)) {
      return luhn(text)
          ? ValidationResult.valid(text)
          : const ValidationResult.invalid('Invalid card number checksum.');
    }
    if (allowMasked &&
        RegExp(r'^[\d*]{16}$').hasMatch(text) &&
        RegExp(r'^\d{4}').hasMatch(text) &&
        RegExp(r'\d{4}$').hasMatch(text)) {
      return ValidationResult.valid(text);
    }
    return const ValidationResult.invalid('Card number must have 16 digits.');
  }

  /// Whether [digits] passes the Luhn checksum.
  static bool luhn(String digits) {
    int sum = 0;
    for (int i = 0; i < digits.length; i++) {
      int d = int.parse(digits[digits.length - 1 - i]);
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    return sum % 10 == 0;
  }
}

/// Iranian IBAN (شبا): `IR` followed by 24 digits, checked with ISO 7064
/// mod 97. The `IR` prefix may be missing. The value is `IR` + 24 digits.
class ShebaValidator implements FieldValidator {
  /// Creates the validator.
  const ShebaValidator();

  @override
  ValidationResult validate(String raw) {
    final String text = TextNormalizer.normalize(raw)
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]'), '');
    final RegExpMatch? m = RegExp(r'^(?:IR)?(\d{24})$').firstMatch(text);
    if (m == null) {
      return const ValidationResult.invalid('Sheba must be IR and 24 digits.');
    }
    final String sheba = 'IR${m[1]}';
    return isValid(sheba)
        ? ValidationResult.valid(sheba)
        : const ValidationResult.invalid('Invalid Sheba checksum.');
  }

  /// Whether [sheba] (`IR` + 24 digits) has correct check digits.
  static bool isValid(String sheba) {
    if (!RegExp(r'^IR\d{24}$').hasMatch(sheba)) return false;
    // I = 18, R = 27.
    final String rearranged =
        '${sheba.substring(4)}1827${sheba.substring(2, 4)}';
    int rem = 0;
    for (final int c in rearranged.codeUnits) {
      rem = (rem * 10 + (c - 48)) % 97;
    }
    return rem == 1;
  }
}

/// Iranian mobile number. Accepts `0912…`, `912…`, `+98912…` and `0098912…`.
/// The value is the 11-digit `09…` form.
class MobileNumberValidator implements FieldValidator {
  /// Creates the validator.
  const MobileNumberValidator();

  @override
  ValidationResult validate(String raw) {
    final String text =
        TextNormalizer.normalize(raw).replaceAll(RegExp(r'[\s\-()]'), '');
    final RegExpMatch? m =
        RegExp(r'^(?:\+98|0098|98|0)?(9\d{9})$').firstMatch(text);
    if (m == null) {
      return const ValidationResult.invalid('Not an Iranian mobile number.');
    }
    return ValidationResult.valid('0${m[1]}');
  }
}

/// A Jalali (Shamsi) date such as `1404/07/27`, `1404-7-27`, `04/07/27` or
/// `27/07/1404`. The value is a `JalaliDate`.
///
/// Two-digit years map to 14xx when below 50 and to 13xx otherwise. With
/// [acceptGregorian], Gregorian dates (year 1900 or later) are accepted too
/// and converted.
class JalaliDateValidator implements FieldValidator {
  /// Creates the validator.
  const JalaliDateValidator({this.acceptGregorian = false});

  /// Whether Gregorian dates are accepted and converted to Jalali.
  final bool acceptGregorian;

  static final RegExp _date =
      RegExp(r'^(\d{2,4})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{1,4})$');

  @override
  ValidationResult validate(String raw) {
    final RegExpMatch? m = _date.firstMatch(TextNormalizer.normalize(raw));
    if (m == null) return const ValidationResult.invalid('Not a date.');
    final int a = int.parse(m[1]!);
    final int month = int.parse(m[2]!);
    final int c = int.parse(m[3]!);
    final int year;
    final int day;
    if (m[3]!.length == 4) {
      year = c;
      day = a;
    } else if (m[1]!.length == 3 || m[3]!.length == 3) {
      return const ValidationResult.invalid('Not a date.');
    } else {
      year = m[1]!.length == 2 ? a + (a < 50 ? 1400 : 1300) : a;
      day = c;
    }
    if (year >= 1900) {
      if (!acceptGregorian ||
          !CalendarConverter.isValidGregorian(year, month, day)) {
        return const ValidationResult.invalid('Not a Jalali date.');
      }
      return ValidationResult.valid(JalaliDate.fromGregorian(year, month, day));
    }
    if (year < 1200 || !CalendarConverter.isValidJalali(year, month, day)) {
      return const ValidationResult.invalid('Not a valid Jalali date.');
    }
    return ValidationResult.valid(JalaliDate(year, month, day));
  }
}
