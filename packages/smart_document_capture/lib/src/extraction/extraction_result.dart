import '../ocr/ocr_result.dart';
import 'confidence.dart';
import 'extracted_field.dart';

/// A change made by a person to an extracted field.
class FieldCorrection {
  /// Creates a correction record.
  const FieldCorrection({
    required this.key,
    required this.previousText,
    required this.newText,
    required this.time,
  });

  /// Key of the corrected field.
  final String key;

  /// Text before the correction (`null` when the field was missing).
  final String? previousText;

  /// Text entered by the person.
  final String newText;

  /// When the correction was made.
  final DateTime time;

  /// Serializes the correction.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'previous': previousText,
        'new': newText,
        'time': time.toIso8601String(),
      };
}

/// Structured data extracted from one document.
class ExtractionResult {
  /// Creates a result.
  const ExtractionResult({
    required this.schemaId,
    required this.fields,
    required this.ocr,
    this.corrections = const <FieldCorrection>[],
  });

  /// [DocumentSchema.id] used for the extraction.
  final String schemaId;

  /// Fields in schema order, by key.
  final Map<String, ExtractedField> fields;

  /// The OCR output the fields were extracted from.
  final OcrResult ocr;

  /// Corrections made by people, oldest first.
  final List<FieldCorrection> corrections;

  /// The field with [key], or `null`.
  ExtractedField? operator [](String key) => fields[key];

  /// Parsed values by key; missing and invalid fields are `null`.
  Map<String, Object?> get values => <String, Object?>{
        for (final ExtractedField f in fields.values) f.key: f.value,
      };

  /// Required fields that are missing or invalid.
  List<ExtractedField> get missingRequired => <ExtractedField>[
        for (final ExtractedField f in fields.values)
          if (f.definition.required && !f.isValid) f,
      ];

  /// Whether every required field has a valid value.
  bool get isComplete => missingRequired.isEmpty;

  /// Average confidence of the fields that were found, or 0.
  double get averageConfidence {
    final List<ExtractedField> found = <ExtractedField>[
      for (final ExtractedField f in fields.values)
        if (!f.isMissing) f,
    ];
    if (found.isEmpty) return 0;
    return found.fold<double>(
            0, (double s, ExtractedField f) => s + f.confidence) /
        found.length;
  }

  /// Fields a person should check: invalid ones, missing required ones and
  /// those below [threshold].
  List<ExtractedField> fieldsToReview({double threshold = 0.85}) =>
      <ExtractedField>[
        for (final ExtractedField f in fields.values)
          if (f.source != FieldSource.user &&
              ((f.isMissing && f.definition.required) ||
                  (!f.isMissing && (!f.isValid || f.confidence < threshold))))
            f,
      ];

  /// Whether [fieldsToReview] is not empty.
  bool needsReview({double threshold = 0.85}) =>
      fieldsToReview(threshold: threshold).isNotEmpty;

  /// Fields grouped by [ConfidenceLevel].
  Map<ConfidenceLevel, List<ExtractedField>> byLevel(
          [ConfidenceThresholds thresholds = const ConfidenceThresholds()]) =>
      <ConfidenceLevel, List<ExtractedField>>{
        for (final ConfidenceLevel level in ConfidenceLevel.values)
          level: <ExtractedField>[
            for (final ExtractedField f in fields.values)
              if (!f.isMissing && f.level(thresholds) == level) f,
          ],
      };

  /// Returns a copy where field [key] holds [text] entered by a person.
  ///
  /// The text is validated, the confidence becomes 1 and the change is
  /// recorded in [corrections]. Throws an [ArgumentError] for unknown keys.
  ExtractionResult correct(String key, String text, {DateTime? time}) {
    final ExtractedField? field = fields[key];
    if (field == null) throw ArgumentError.value(key, 'key', 'Unknown field');
    return ExtractionResult(
      schemaId: schemaId,
      ocr: ocr,
      fields: <String, ExtractedField>{
        ...fields,
        key: field.correctedWith(text),
      },
      corrections: <FieldCorrection>[
        ...corrections,
        FieldCorrection(
          key: key,
          previousText: field.rawText,
          newText: text,
          time: time ?? DateTime.now(),
        ),
      ],
    );
  }

  /// Serializes the result. Set [includeOcr] to embed the raw OCR output.
  Map<String, dynamic> toJson({bool includeOcr = false}) => <String, dynamic>{
        'schema': schemaId,
        'engine': ocr.engine,
        'complete': isComplete,
        'confidence': averageConfidence,
        'fields': <String, dynamic>{
          for (final ExtractedField f in fields.values) f.key: f.toJson(),
        },
        if (corrections.isNotEmpty)
          'corrections': <Map<String, dynamic>>[
            for (final FieldCorrection c in corrections) c.toJson(),
          ],
        if (includeOcr) 'ocr': ocr.toJson(),
      };
}
