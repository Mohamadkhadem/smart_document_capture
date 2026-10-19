import '../geometry/bounding_box.dart';
import '../validation/field_validator.dart';
import 'confidence.dart';
import 'field_definition.dart';

/// Where the value of an [ExtractedField] comes from.
enum FieldSource {
  /// Found by OCR and the field's locators.
  ocr,

  /// Entered or corrected by a person.
  user,

  /// Not found.
  missing,
}

/// Another value considered for a field, kept so a reviewer can switch to it.
class FieldAlternative {
  /// Creates an alternative.
  const FieldAlternative({
    required this.rawText,
    required this.value,
    required this.confidence,
    this.box,
  });

  /// Text found in the document.
  final String rawText;

  /// Parsed value, or `null` when the text failed validation.
  final Object? value;

  /// Confidence of this alternative.
  final double confidence;

  /// Location in the image.
  final BoundingBox? box;

  /// Serializes the alternative.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'raw': rawText,
        'value': jsonValue(value),
        'confidence': confidence,
        if (box != null) 'box': box!.toJson(),
      };
}

/// The result for one field of a document.
class ExtractedField {
  /// Creates a field result.
  const ExtractedField({
    required this.definition,
    required this.rawText,
    required this.value,
    required this.confidence,
    required this.source,
    this.box,
    this.error,
    this.alternatives = const <FieldAlternative>[],
  });

  /// A field that was not found.
  const ExtractedField.missing(this.definition)
      : rawText = null,
        value = null,
        confidence = 0,
        source = FieldSource.missing,
        box = null,
        error = null,
        alternatives = const <FieldAlternative>[];

  /// The definition the field was extracted with.
  final FieldDefinition definition;

  /// Text read from the document or typed by the user.
  final String? rawText;

  /// Parsed value; `null` when missing or invalid. See [FieldType] for the
  /// type of each kind of field.
  final Object? value;

  /// Confidence between 0 and 1. Values entered by a user have 1.
  final double confidence;

  /// Where the value comes from.
  final FieldSource source;

  /// Location of the text in the image.
  final BoundingBox? box;

  /// Validation message when [rawText] is not valid.
  final String? error;

  /// Other candidates, best first.
  final List<FieldAlternative> alternatives;

  /// Identifier of the field.
  String get key => definition.key;

  /// Human readable name of the field.
  String get label => definition.label;

  /// Whether nothing was found or entered.
  bool get isMissing => source == FieldSource.missing;

  /// Whether the field has text that passed validation.
  bool get isValid => !isMissing && error == null;

  /// [confidence] as a [ConfidenceLevel].
  ConfidenceLevel level(
          [ConfidenceThresholds thresholds = const ConfidenceThresholds()]) =>
      ConfidenceLevel.of(confidence, thresholds);

  /// Returns this field with [text] entered by a user.
  ///
  /// The text is checked with the field's validator; the confidence becomes
  /// 1 because a person confirmed it.
  ExtractedField correctedWith(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ExtractedField(
        definition: definition,
        rawText: '',
        value: null,
        confidence: 1,
        source: FieldSource.user,
        box: box,
        error: definition.required ? 'Required.' : null,
        alternatives: alternatives,
      );
    }
    final ValidationResult? v = definition.validator?.validate(trimmed);
    return ExtractedField(
      definition: definition,
      rawText: trimmed,
      value: v == null ? trimmed : v.value,
      confidence: 1,
      source: FieldSource.user,
      box: box,
      error: v == null || v.isValid ? null : v.message,
      alternatives: alternatives,
    );
  }

  /// Serializes the field. Dates become `yyyy/MM/dd` strings.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'label': label,
        'type': definition.type.name,
        'value': jsonValue(value),
        'raw': rawText,
        'confidence': confidence,
        'source': source.name,
        'valid': isValid,
        if (error != null) 'error': error,
        if (box != null) 'box': box!.toJson(),
        if (alternatives.isNotEmpty)
          'alternatives': <Map<String, dynamic>>[
            for (final FieldAlternative a in alternatives) a.toJson(),
          ],
      };

  @override
  String toString() =>
      'ExtractedField($key: $value, ${confidence.toStringAsFixed(2)}, ${source.name})';
}

/// Converts a field value into something `jsonEncode` accepts.
Object? jsonValue(Object? value) => switch (value) {
      null || num() || String() || bool() => value,
      _ => value.toString(),
    };
