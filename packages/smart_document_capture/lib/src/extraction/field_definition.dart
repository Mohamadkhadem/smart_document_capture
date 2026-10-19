import '../validation/field_validator.dart';
import 'field_locator.dart';

/// Kind of data a field holds. Used by the review UI to pick a keyboard and
/// by consumers to interpret [ExtractedField.value].
enum FieldType {
  /// Free text; the value is a `String`.
  text,

  /// A number; the value is a `num`.
  number,

  /// A monetary amount; the value is a `num`.
  amount,

  /// A date; the value is a `JalaliDate`.
  date,

  /// A time of day; the value is a `String` such as `14:35`.
  time,

  /// An Iranian national code; the value is a 10-digit `String`.
  nationalCode,

  /// A bank card number; the value is a 16-character `String`.
  cardNumber,

  /// An Iranian IBAN (Sheba); the value is a `String`.
  sheba,

  /// A phone number; the value is a `String`.
  phone,

  /// An identifier such as an invoice or tracking number; a `String`.
  identifier,
}

/// Describes one field of a document: how to find it and how to check it.
class FieldDefinition {
  /// Creates a definition.
  const FieldDefinition({
    required this.key,
    required this.label,
    required this.locators,
    this.type = FieldType.text,
    this.validator,
    this.required = false,
    this.pickLast = false,
  });

  /// Identifier of the field in results and JSON, e.g. `total`.
  final String key;

  /// Human readable name shown in the review UI.
  final String label;

  /// Kind of data the field holds.
  final FieldType type;

  /// Strategies used to find candidate texts.
  final List<FieldLocator> locators;

  /// Parses and checks candidates; without one every non-empty text is
  /// accepted as a `String`.
  final FieldValidator? validator;

  /// Whether the document is incomplete without this field.
  final bool required;

  /// When candidates score the same, prefer the one lower in the document.
  /// Useful for totals, which come after subtotals.
  final bool pickLast;
}
