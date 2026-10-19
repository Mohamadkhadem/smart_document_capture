import 'dart:typed_data';

import 'ocr_result.dart';

/// The image an [OcrEngine] should analyze.
///
/// Engines may support only some of the sources; they throw an
/// [OcrException] for the others.
class DocumentImage {
  /// An image stored in a file on the device.
  const DocumentImage.file(String this.path) : bytes = null;

  /// An encoded image (PNG, JPEG, ...) held in memory.
  const DocumentImage.bytes(Uint8List this.bytes) : path = null;

  /// File path of the image, for [DocumentImage.file].
  final String? path;

  /// Encoded image bytes, for [DocumentImage.bytes].
  final Uint8List? bytes;

  @override
  String toString() => path != null
      ? 'DocumentImage.file($path)'
      : 'DocumentImage.bytes(${bytes!.length} bytes)';
}

/// Options passed to [OcrEngine.recognize].
class OcrOptions {
  /// Creates options.
  const OcrOptions({
    this.languages = const <String>['fas', 'eng'],
    this.extra = const <String, Object?>{},
  });

  /// Languages to recognize, as ISO 639-2 codes (`fas`, `eng`, `ara`, ...).
  ///
  /// Engines map them to their own identifiers.
  final List<String> languages;

  /// Engine specific settings.
  final Map<String, Object?> extra;
}

/// A text recognition engine.
///
/// Implement this interface to plug any OCR library into
/// `smart_document_capture`. The engine only turns pixels into text; field
/// extraction, validation and confidence scoring happen in the core.
abstract interface class OcrEngine {
  /// Short identifier of the engine, stored in [OcrResult.engine].
  String get name;

  /// Recognizes the text in [image].
  ///
  /// Throws an [OcrException] when recognition fails.
  Future<OcrResult> recognize(
    DocumentImage image, {
    OcrOptions options = const OcrOptions(),
  });

  /// Releases resources held by the engine.
  Future<void> dispose();
}

/// Thrown when an [OcrEngine] cannot analyze an image.
class OcrException implements Exception {
  /// Creates the exception.
  const OcrException(this.message, {this.cause});

  /// Human readable description.
  final String message;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() =>
      cause == null ? 'OcrException: $message' : 'OcrException: $message ($cause)';
}
