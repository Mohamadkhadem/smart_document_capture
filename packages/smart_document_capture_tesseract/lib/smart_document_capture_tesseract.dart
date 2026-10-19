/// Offline Tesseract engine for `smart_document_capture`.
///
/// ```dart
/// final capture = DocumentCapture(engine: TesseractOcrEngine());
/// final result = await capture.process(
///   DocumentImage.file(path),
///   ReceiptSchema.persian,
/// );
/// ```
library;

export 'src/hocr_parser.dart';
export 'src/tesseract_ocr_engine.dart';
