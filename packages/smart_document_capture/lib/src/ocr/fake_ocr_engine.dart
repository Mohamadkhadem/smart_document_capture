import 'ocr_engine.dart';
import 'ocr_result.dart';

/// An [OcrEngine] that returns a prepared result.
///
/// Use it in tests, demos and while designing a schema, before a real engine
/// is wired in.
class FakeOcrEngine implements OcrEngine {
  /// Always returns [result].
  FakeOcrEngine(OcrResult result) : _resolve = ((_) => result);

  /// Returns [text] as a single block, one [OcrLine] per line.
  FakeOcrEngine.text(String text, {double confidence = 0.95})
      : _resolve = ((_) =>
            OcrResult.fromText(text, confidence: confidence, engine: 'fake'));

  /// Computes the result for each image.
  FakeOcrEngine.from(OcrResult Function(DocumentImage image) resolve)
      : _resolve = resolve;

  final OcrResult Function(DocumentImage image) _resolve;

  /// Images passed to [recognize], in call order.
  final List<DocumentImage> calls = <DocumentImage>[];

  @override
  String get name => 'fake';

  @override
  Future<OcrResult> recognize(
    DocumentImage image, {
    OcrOptions options = const OcrOptions(),
  }) async {
    calls.add(image);
    return _resolve(image);
  }

  @override
  Future<void> dispose() async {}
}
