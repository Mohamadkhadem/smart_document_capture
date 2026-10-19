import '../ocr/ocr_result.dart';
import '../text/text_normalizer.dart';
import '../validation/field_validator.dart';
import 'confidence.dart';
import 'document_schema.dart';
import 'document_text.dart';
import 'extracted_field.dart';
import 'extraction_result.dart';
import 'field_definition.dart';
import 'field_locator.dart';

/// Extracts the fields of a [DocumentSchema] from an [OcrResult].
///
/// This is the synchronous, engine independent part of the pipeline, so it
/// can be unit tested with `OcrResult.fromText`.
class DocumentExtractor {
  /// Creates an extractor.
  const DocumentExtractor({
    this.confidenceModel = const DefaultConfidenceModel(),
    this.maxAlternatives = 3,
  });

  /// Scores candidates.
  final ConfidenceModel confidenceModel;

  /// How many alternatives are kept per field.
  final int maxAlternatives;

  /// Extracts every field of [schema] from [ocr].
  ExtractionResult extract(OcrResult ocr, DocumentSchema schema) {
    final DocumentText document = DocumentText(ocr);
    return ExtractionResult(
      schemaId: schema.id,
      ocr: ocr,
      fields: <String, ExtractedField>{
        for (final FieldDefinition f in schema.fieldsFor(document))
          f.key: extractField(document, f),
      },
    );
  }

  /// Extracts one field.
  ExtractedField extractField(DocumentText document, FieldDefinition field) {
    final List<_Scored> scored = <_Scored>[];
    for (final FieldLocator locator in field.locators) {
      for (final FieldCandidate c in locator.locate(document)) {
        if (c.rawText.isEmpty) continue;
        final ValidationResult? v = field.validator?.validate(c.rawText);
        final Object? value =
            v == null ? TextNormalizer.normalize(c.rawText) : v.value;
        scored.add(_Scored(c, v, value));
      }
    }
    if (scored.isEmpty) return ExtractedField.missing(field);

    // Count candidates agreeing on each valid value.
    final Map<String, int> votes = <String, int>{};
    for (final _Scored s in scored) {
      if (s.validation?.isValid ?? true) {
        final String k = s.value.toString();
        votes[k] = (votes[k] ?? 0) + 1;
      }
    }
    for (final _Scored s in scored) {
      final int agreeing = (s.validation?.isValid ?? true)
          ? votes[s.value.toString()]! - 1
          : 0;
      s.score = confidenceModel.score(s.candidate, s.validation,
          agreeing: agreeing);
    }

    scored.sort((_Scored a, _Scored b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0 || !field.pickLast) return byScore;
      return (b.candidate.lineIndex ?? 0).compareTo(a.candidate.lineIndex ?? 0);
    });

    final _Scored best = scored.first;
    final Set<String> seen = <String>{best.candidate.rawText};
    final List<FieldAlternative> alternatives = <FieldAlternative>[];
    for (final _Scored s in scored.skip(1)) {
      if (alternatives.length >= maxAlternatives) break;
      if (!seen.add(s.candidate.rawText)) continue;
      alternatives.add(FieldAlternative(
        rawText: s.candidate.rawText,
        value: (s.validation?.isValid ?? true) ? s.value : null,
        confidence: s.score,
        box: s.candidate.box,
      ));
    }

    final bool valid = best.validation?.isValid ?? true;
    return ExtractedField(
      definition: field,
      rawText: best.candidate.rawText,
      value: valid ? best.value : null,
      confidence: best.score,
      source: FieldSource.ocr,
      box: best.candidate.box,
      error: valid ? null : best.validation!.message,
      alternatives: alternatives,
    );
  }
}

class _Scored {
  _Scored(this.candidate, this.validation, this.value);

  final FieldCandidate candidate;
  final ValidationResult? validation;
  final Object? value;
  double score = 0;
}
