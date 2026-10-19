import '../geometry/bounding_box.dart';
import '../ocr/ocr_result.dart';
import '../text/text_normalizer.dart';

/// One OCR line prepared for searching.
///
/// [text] is the normalized text of the line (see [TextNormalizer.normalize]),
/// built word by word so a character range can be mapped back to the words,
/// their boxes and their confidence.
class DocumentLine {
  DocumentLine._(this.index, this.source, this.text, this._wordStarts);

  factory DocumentLine._build(int index, OcrLine line) {
    final StringBuffer b = StringBuffer();
    final List<int> starts = <int>[];
    for (final OcrWord w in line.words) {
      if (b.isNotEmpty) b.write(' ');
      starts.add(b.length);
      b.write(TextNormalizer.normalize(w.text));
    }
    return DocumentLine._(index, line, b.toString(), starts);
  }

  /// Position of the line in the document.
  final int index;

  /// The OCR line.
  final OcrLine source;

  /// Normalized text of the line.
  final String text;

  final List<int> _wordStarts;

  /// Words overlapping the character range `[start, end)` of [text].
  List<OcrWord> wordsInRange(int start, int end) {
    final List<OcrWord> result = <OcrWord>[];
    for (int i = 0; i < _wordStarts.length; i++) {
      final int ws = _wordStarts[i];
      final int we =
          i + 1 < _wordStarts.length ? _wordStarts[i + 1] - 1 : text.length;
      if (ws < end && we > start) result.add(source.words[i]);
    }
    return result;
  }
}

/// An [OcrResult] prepared for field locators.
class DocumentText {
  /// Prepares [ocr].
  DocumentText(this.ocr)
      : lines = <DocumentLine>[
          for (final (int i, OcrLine l) in ocr.lines.indexed)
            DocumentLine._build(i, l),
        ];

  /// The OCR output.
  final OcrResult ocr;

  /// Lines in reading order.
  final List<DocumentLine> lines;

  /// Location and average confidence of the characters `[start, end)` of
  /// line [line].
  ({BoundingBox? box, double confidence}) span(
      DocumentLine line, int start, int end) {
    final List<OcrWord> words = line.wordsInRange(start, end);
    if (words.isEmpty) {
      return (box: line.source.box, confidence: line.source.confidence);
    }
    final double conf =
        words.fold<double>(0, (double s, OcrWord w) => s + w.confidence) /
            words.length;
    return (
      box: BoundingBox.unionAll(words.map((OcrWord w) => w.box)),
      confidence: conf
    );
  }
}
