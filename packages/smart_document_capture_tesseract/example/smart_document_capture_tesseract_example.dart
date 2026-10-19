// Reads a receipt photo with Tesseract and prints the extracted fields.
//
// The app must bundle `assets/tessdata_config.json` and the trained data
// (see the package README).
import 'package:smart_document_capture/smart_document_capture.dart';
import 'package:smart_document_capture_tesseract/smart_document_capture_tesseract.dart';

Future<void> readReceipt(String imagePath) async {
  final DocumentCapture capture = DocumentCapture(
    engine: TesseractOcrEngine(),
    options: const OcrOptions(languages: <String>['fas', 'eng']),
  );

  final ExtractionResult result = await capture.process(
    DocumentImage.file(imagePath),
    ReceiptSchema.persian,
  );

  for (final ExtractedField field in result.fields.values) {
    // ignore: avoid_print
    print('${field.label}: ${field.value} '
        '(${(field.confidence * 100).round()}%)');
  }
  if (result.needsReview()) {
    // Show DocumentReviewView so a person can check the doubtful fields.
  }
  await capture.dispose();
}
