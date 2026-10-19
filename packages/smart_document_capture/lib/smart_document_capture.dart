/// Extract structured data from document, receipt and form images.
///
/// * [OcrEngine]: plug in any OCR library (see
///   `smart_document_capture_tesseract` for an offline engine).
/// * [DocumentSchema], [FieldDefinition] and [FieldLocator]s describe what to
///   extract; [ReceiptSchema] and [KeyValueSchema] are ready to use.
/// * [DocumentCapture] runs the pipeline and returns an [ExtractionResult]
///   with a confidence score for every field.
/// * [DocumentReviewView] lets a person check and correct the result.
library;

export 'src/document_capture.dart';
export 'src/extraction/confidence.dart';
export 'src/extraction/document_extractor.dart';
export 'src/extraction/document_schema.dart';
export 'src/extraction/document_text.dart';
export 'src/extraction/extracted_field.dart';
export 'src/extraction/extraction_result.dart';
export 'src/extraction/field_definition.dart';
export 'src/extraction/field_locator.dart';
export 'src/geometry/bounding_box.dart';
export 'src/ocr/fake_ocr_engine.dart';
export 'src/ocr/ocr_engine.dart';
export 'src/ocr/ocr_result.dart';
export 'src/schemas/key_value_schema.dart';
export 'src/schemas/patterns.dart';
export 'src/schemas/receipt_schema.dart';
export 'src/text/text_normalizer.dart';
export 'src/validation/field_validator.dart';
export 'src/validation/iranian_validators.dart';
export 'src/widgets/document_review_controller.dart';
export 'src/widgets/document_review_view.dart';
export 'src/widgets/review_strings.dart';
