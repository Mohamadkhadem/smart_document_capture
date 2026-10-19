import 'package:smart_document_capture/smart_document_capture.dart';

/// Converts Tesseract hOCR output into an [OcrResult].
///
/// Paragraphs (`ocr_par`) become blocks, `ocr_line` (and `ocr_header`,
/// `ocr_caption`, `ocr_textfloat`) become lines and `ocrx_word` become
/// words with their `bbox` and `x_wconf` (scaled to 0–1). The page `bbox`
/// gives the image size. Words keep Tesseract's reading order, which is
/// right to left for Persian.
abstract final class HocrParser {
  static final RegExp _tag = RegExp(r'<(div|p|span)\b([^>]*)>');
  static final RegExp _class = RegExp(r'''class=(['"])([^'"]*)\1''');
  static final RegExp _title = RegExp(r'''title=(['"])(.*?)\1''');
  static final RegExp _bbox =
      RegExp(r'bbox\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)');
  static final RegExp _wconf = RegExp(r'x_wconf\s+(\d+(?:\.\d+)?)');

  static const Set<String> _lineClasses = <String>{
    'ocr_line',
    'ocr_header',
    'ocr_caption',
    'ocr_textfloat',
  };

  /// Parses [hocr]. Returns [OcrResult.empty]-like output for empty input.
  static OcrResult parse(String hocr, {String engine = 'tesseract'}) {
    double? width;
    double? height;
    final List<OcrBlock> blocks = <OcrBlock>[];
    List<OcrLine> lines = <OcrLine>[];
    List<OcrWord>? words;
    BoundingBox? lineBox;

    void closeLine() {
      if (words != null && words!.isNotEmpty) {
        lines.add(OcrLine(words: words!, box: lineBox));
      }
      words = null;
      lineBox = null;
    }

    void closeBlock() {
      closeLine();
      if (lines.isNotEmpty) blocks.add(OcrBlock(lines: lines));
      lines = <OcrLine>[];
    }

    for (final RegExpMatch m in _tag.allMatches(hocr)) {
      final String attrs = m[2]!;
      final String? cls = _class.firstMatch(attrs)?[2];
      if (cls == null) continue;
      final String title = _title.firstMatch(attrs)?[2] ?? '';
      final BoundingBox? box = _parseBox(title);

      if (cls == 'ocr_page') {
        closeBlock();
        if (box != null) {
          width = box.width;
          height = box.height;
        }
      } else if (cls == 'ocr_carea' || cls == 'ocr_par') {
        closeBlock();
      } else if (_lineClasses.contains(cls)) {
        closeLine();
        words = <OcrWord>[];
        lineBox = box;
      } else if (cls == 'ocrx_word') {
        final int end = hocr.indexOf('</span>', m.end);
        final String text = _unescape(
                _stripTags(hocr.substring(m.end, end < 0 ? hocr.length : end)))
            .trim();
        if (text.isEmpty) continue;
        final double conf =
            double.parse(_wconf.firstMatch(title)?[1] ?? '100') / 100;
        (words ??= <OcrWord>[])
            .add(OcrWord(text: text, box: box, confidence: conf.clamp(0, 1)));
      }
    }
    closeBlock();

    return OcrResult(
      blocks: blocks,
      imageWidth: width,
      imageHeight: height,
      engine: engine,
    );
  }

  static BoundingBox? _parseBox(String title) {
    final RegExpMatch? b = _bbox.firstMatch(title);
    if (b == null) return null;
    return BoundingBox.fromLTRB(double.parse(b[1]!), double.parse(b[2]!),
        double.parse(b[3]!), double.parse(b[4]!));
  }

  static String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  static String _unescape(String s) => s
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
          (Match m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (Match m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
