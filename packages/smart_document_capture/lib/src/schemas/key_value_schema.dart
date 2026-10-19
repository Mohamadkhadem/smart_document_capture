import '../extraction/document_schema.dart';
import '../extraction/document_text.dart';
import '../extraction/field_definition.dart';
import '../extraction/field_locator.dart';
import '../validation/field_validator.dart';
import '../validation/iranian_validators.dart';

/// Extracts every `label: value` line of a document as a field.
///
/// The field key is the label in snake case (`نام خانوادگی` →
/// `نام_خانوادگی`), so the fields depend on the document. With [inferTypes]
/// each value is tried as a date, time, mobile number, national code, card
/// number, Sheba and amount, and gets the first type that validates.
class KeyValueSchema extends DocumentSchema {
  /// Creates the schema.
  const KeyValueSchema({
    this.separators = const <String>[':', '：'],
    this.inferTypes = true,
    this.score = 0.95,
  }) : super(
            id: 'key_value',
            name: 'Key / value',
            fields: const <FieldDefinition>[]);

  /// Characters that separate a label from its value.
  final List<String> separators;

  /// Whether value types are detected.
  final bool inferTypes;

  /// Match score of the values.
  final double score;

  static const List<(FieldType, FieldValidator)> _inference =
      <(FieldType, FieldValidator)>[
    (FieldType.date, JalaliDateValidator(acceptGregorian: true)),
    (FieldType.time, TimeValidator()),
    (FieldType.sheba, ShebaValidator()),
    (FieldType.cardNumber, BankCardValidator()),
    (FieldType.nationalCode, _StrictNationalCode()),
    (FieldType.phone, MobileNumberValidator()),
    (FieldType.amount, AmountValidator(allowZero: true)),
  ];

  @override
  List<FieldDefinition> fieldsFor(DocumentText document) {
    final List<FieldDefinition> result = <FieldDefinition>[];
    final Map<String, int> used = <String, int>{};
    for (final DocumentLine line in document.lines) {
      int sep = -1;
      for (final String s in separators) {
        final int i = line.text.indexOf(s);
        if (i > 0 && (sep < 0 || i < sep)) sep = i;
      }
      if (sep < 0) continue;
      final String label = line.text.substring(0, sep).trim();
      final String value = line.text.substring(sep + 1).trim();
      if (value.isEmpty ||
          RegExp(r'[A-Za-z؀-ۿ]').allMatches(label).length < 2) {
        continue;
      }
      String key = label.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final int n = (used[key] ?? 0) + 1;
      used[key] = n;
      if (n > 1) key = '${key}_$n';

      FieldType type = FieldType.text;
      FieldValidator? validator;
      if (inferTypes) {
        for (final (FieldType t, FieldValidator v) in _inference) {
          if (v.validate(value).isValid) {
            type = t;
            validator = v;
            break;
          }
        }
      }
      final int start = line.text.indexOf(value, sep + 1);
      result.add(FieldDefinition(
        key: key,
        label: label,
        type: type,
        validator: validator,
        locators: <FieldLocator>[
          _SpanLocator(line.index, start, start + value.length, score),
        ],
      ));
    }
    return result;
  }
}

/// National codes must be exactly 10 digits here, so short numbers are not
/// mistaken for padded codes.
class _StrictNationalCode implements FieldValidator {
  const _StrictNationalCode();

  @override
  ValidationResult validate(String raw) =>
      RegExp(r'^\d{3}-?\d{6}-?\d$').hasMatch(raw.trim())
          ? const NationalCodeValidator().validate(raw)
          : const ValidationResult.invalid('Not a national code.');
}

class _SpanLocator implements FieldLocator {
  const _SpanLocator(this.line, this.start, this.end, this.score);

  final int line;
  final int start;
  final int end;
  final double score;

  @override
  List<FieldCandidate> locate(DocumentText document) {
    final DocumentLine l = document.lines[line];
    final s = document.span(l, start, end);
    return <FieldCandidate>[
      FieldCandidate(
        rawText: l.text.substring(start, end),
        matchScore: score,
        ocrConfidence: s.confidence,
        locator: 'key/value',
        box: s.box,
        lineIndex: line,
      ),
    ];
  }
}
