import 'extraction/document_extractor.dart';
import 'extraction/document_schema.dart';
import 'extraction/extraction_result.dart';
import 'ocr/ocr_engine.dart';
import 'ocr/ocr_result.dart';

/// The full pipeline: image → [OcrEngine] → [DocumentExtractor] → result.
///
/// ```dart
/// final capture = DocumentCapture(engine: TesseractOcrEngine());
/// final result = await capture.process(
///   const DocumentImage.file('/path/receipt.jpg'),
///   ReceiptSchema.persian,
/// );
/// print(result['total']?.value);
/// ```
class DocumentCapture {
  /// Creates a pipeline around [engine].
  const DocumentCapture({
    required this.engine,
    this.extractor = const DocumentExtractor(),
    this.options = const OcrOptions(),
  });

  /// Engine that turns images into text.
  final OcrEngine engine;

  /// Turns text into fields.
  final DocumentExtractor extractor;

  /// Options passed to the engine.
  final OcrOptions options;

  /// Recognizes [image] and extracts the fields of [schema].
  ///
  /// Throws an [OcrException] when the engine fails.
  Future<ExtractionResult> process(
      DocumentImage image, DocumentSchema schema) async {
    final OcrResult ocr = await engine.recognize(image, options: options);
    return extractor.extract(ocr, schema);
  }

  /// Extracts [schema] from an existing OCR result, without the engine.
  ExtractionResult extract(OcrResult ocr, DocumentSchema schema) =>
      extractor.extract(ocr, schema);

  /// Releases the engine.
  Future<void> dispose() => engine.dispose();
}
