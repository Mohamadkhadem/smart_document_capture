import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:smart_document_capture/smart_document_capture.dart';

import 'hocr_parser.dart';

/// Runs Tesseract on an image and returns its hOCR output.
///
/// [language] uses Tesseract's `+` syntax, e.g. `fas+eng`.
typedef HocrRecognizer = Future<String> Function(
    String imagePath, String language, Map<String, String> args);

/// An offline [OcrEngine] backed by Tesseract through the
/// `flutter_tesseract_ocr` plugin (Android and iOS).
///
/// The app must bundle the trained data of every language it uses; see the
/// package README. Only [DocumentImage.file] images are supported.
class TesseractOcrEngine implements OcrEngine {
  /// Creates the engine.
  ///
  /// [args] are Tesseract variables. The default page segmentation mode
  /// `psm 4` (a single column of text of variable sizes) suits receipts;
  /// use `3` for full pages. [recognizer] replaces the plugin call, for tests
  /// or another Tesseract binding.
  TesseractOcrEngine({
    this.args = const <String, String>{
      'psm': '4',
      'preserve_interword_spaces': '1',
    },
    HocrRecognizer? recognizer,
  }) : _recognizer = recognizer ?? _plugin;

  /// Tesseract variables passed on every call.
  final Map<String, String> args;

  final HocrRecognizer _recognizer;

  static Future<String> _plugin(
          String imagePath, String language, Map<String, String> args) =>
      FlutterTesseractOcr.extractHocr(imagePath, language: language, args: args);

  @override
  String get name => 'tesseract';

  @override
  Future<OcrResult> recognize(
    DocumentImage image, {
    OcrOptions options = const OcrOptions(),
  }) async {
    final String? path = image.path;
    if (path == null) {
      throw const OcrException(
          'TesseractOcrEngine needs DocumentImage.file; save the bytes to a file first.');
    }
    final String language = options.languages.join('+');
    final Map<String, String> callArgs = <String, String>{
      ...args,
      for (final MapEntry<String, Object?> e in options.extra.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    final String hocr;
    try {
      hocr = await _recognizer(path, language, callArgs);
    } catch (e) {
      throw OcrException('Tesseract failed.', cause: e);
    }
    return HocrParser.parse(hocr, engine: name);
  }

  @override
  Future<void> dispose() async {}
}
