import '../geometry/bounding_box.dart';
import '../ocr/ocr_result.dart';
import '../text/text_normalizer.dart';
import 'document_text.dart';

/// A possible value for a field, found by a [FieldLocator].
class FieldCandidate {
  /// Creates a candidate.
  const FieldCandidate({
    required this.rawText,
    required this.matchScore,
    required this.ocrConfidence,
    required this.locator,
    this.box,
    this.lineIndex,
  });

  /// Text found in the document.
  final String rawText;

  /// How strongly the locator believes this is the field, between 0 and 1.
  final double matchScore;

  /// Average OCR confidence of the words behind [rawText].
  final double ocrConfidence;

  /// Description of the locator that produced the candidate.
  final String locator;

  /// Location of [rawText] in the image, when known.
  final BoundingBox? box;

  /// Line of the document the text came from.
  final int? lineIndex;

  @override
  String toString() =>
      'FieldCandidate($rawText, match: $matchScore, ocr: $ocrConfidence, $locator)';
}

/// A strategy that searches the document for the text of a field.
///
/// A field may combine several locators; every candidate they return is
/// validated and scored, and the best one wins.
abstract interface class FieldLocator {
  /// Returns every candidate found in [document].
  List<FieldCandidate> locate(DocumentText document);
}

FieldCandidate _candidate(DocumentText doc, DocumentLine line, int start,
    int end, double score, String locator) {
  final ({BoundingBox? box, double confidence}) s = doc.span(line, start, end);
  return FieldCandidate(
    rawText: line.text.substring(start, end).trim(),
    matchScore: score,
    ocrConfidence: s.confidence,
    locator: locator,
    box: s.box,
    lineIndex: line.index,
  );
}

/// Finds every match of [pattern] in every line.
///
/// Lines are normalized first: digits are English and Arabic letters are
/// Persian, so write patterns with `\d` and Persian letters.
class PatternLocator implements FieldLocator {
  /// Creates the locator.
  const PatternLocator(this.pattern, {this.group = 0, this.score = 0.75});

  /// Pattern searched in each normalized line.
  final RegExp pattern;

  /// Capture group used as the value; 0 is the whole match.
  final int group;

  /// [FieldCandidate.matchScore] of the candidates.
  final double score;

  @override
  List<FieldCandidate> locate(DocumentText document) {
    final List<FieldCandidate> result = <FieldCandidate>[];
    for (final DocumentLine line in document.lines) {
      for (final RegExpMatch m in pattern.allMatches(line.text)) {
        final String? g = m.group(group);
        if (g == null || g.trim().isEmpty) continue;
        final int start = m.start + m.group(0)!.indexOf(g);
        result.add(_candidate(document, line, start, start + g.length, score,
            'pattern ${pattern.pattern}'));
      }
    }
    return result;
  }
}

/// Finds a label such as `جمع کل:` and reads the value next to it.
///
/// The value is searched, in order:
/// 1. after the keyword on the same line ([sameLineScore]),
/// 2. before the keyword on the same line, for layouts where OCR puts the
///    value first ([sameLineScore] × 0.9),
/// 3. on the following line, when [searchNextLine] is set ([nextLineScore]).
///
/// Without a [value] pattern, the rest of the line after the keyword is the
/// value.
class KeywordLocator implements FieldLocator {
  /// Creates the locator.
  const KeywordLocator(
    this.keywords, {
    this.value,
    this.sameLineScore = 0.95,
    this.nextLineScore = 0.8,
    this.searchNextLine = true,
  });

  /// Labels to look for. Matching ignores case, digits style, Arabic/Persian
  /// letter variants and the amount of whitespace.
  final List<String> keywords;

  /// Pattern of the value, e.g. an amount or a date.
  final RegExp? value;

  /// Score of a value found on the keyword's line.
  final double sameLineScore;

  /// Score of a value found on the next line.
  final double nextLineScore;

  /// Whether to look on the next line when the keyword's line has no value.
  final bool searchNextLine;

  static final RegExp _separators = RegExp(r'^[\s:：\-=.]+|[\s:：\-=]+$');

  RegExp _keywordPattern(String keyword) {
    final String k = TextNormalizer.normalize(keyword)
        .split(' ')
        .map(RegExp.escape)
        .join(r'\s*');
    return RegExp(k, caseSensitive: false);
  }

  @override
  List<FieldCandidate> locate(DocumentText document) {
    final List<FieldCandidate> result = <FieldCandidate>[];
    for (final String keyword in keywords) {
      final RegExp kp = _keywordPattern(keyword);
      final String name = 'keyword "$keyword"';
      for (final DocumentLine line in document.lines) {
        final RegExpMatch? k = kp.firstMatch(line.text);
        if (k == null) continue;
        final FieldCandidate? found = _inRange(
                document, line, k.end, line.text.length, sameLineScore, name) ??
            _inRange(document, line, 0, k.start, sameLineScore * 0.9, name);
        if (found != null) {
          result.add(found);
          continue;
        }
        if (searchNextLine && line.index + 1 < document.lines.length) {
          final DocumentLine next = document.lines[line.index + 1];
          final FieldCandidate? below = _inRange(
              document, next, 0, next.text.length, nextLineScore, name);
          if (below != null) result.add(below);
        }
      }
    }
    return result;
  }

  FieldCandidate? _inRange(DocumentText doc, DocumentLine line, int start,
      int end, double score, String name) {
    final String part = line.text.substring(start, end);
    if (value == null) {
      final String trimmed = part.replaceAll(_separators, '');
      if (trimmed.isEmpty) return null;
      final int s = start + part.indexOf(trimmed);
      return _candidate(doc, line, s, s + trimmed.length, score, name);
    }
    final RegExpMatch? m = value!.firstMatch(part);
    if (m == null || m.group(0)!.trim().isEmpty) return null;
    return _candidate(
        doc, line, start + m.start, start + m.end, score, name);
  }
}

/// Reads the words inside a region of the page.
///
/// [region] uses fractions of the image size (0 to 1), so the same schema
/// works for photos of any resolution. Requires an engine that reports word
/// boxes and the image size.
class RegionLocator implements FieldLocator {
  /// Creates the locator.
  const RegionLocator(this.region, {this.value, this.score = 0.7});

  /// Region in fractions of the image width and height.
  final BoundingBox region;

  /// Optional pattern the region text must contain.
  final RegExp? value;

  /// [FieldCandidate.matchScore] of the candidate.
  final double score;

  @override
  List<FieldCandidate> locate(DocumentText document) {
    final double? w = document.ocr.imageWidth;
    final double? h = document.ocr.imageHeight;
    if (w == null || h == null) return const <FieldCandidate>[];
    final BoundingBox area = region.scale(w, h);
    final List<FieldCandidate> result = <FieldCandidate>[];
    for (final DocumentLine line in document.lines) {
      final List<OcrWord> inside = <OcrWord>[
        for (final OcrWord word in line.source.words)
          if (word.box != null && area.containsCenterOf(word.box!)) word,
      ];
      if (inside.isEmpty) continue;
      final String text = TextNormalizer.normalize(
          inside.map((OcrWord word) => word.text).join(' '));
      String raw = text;
      if (value != null) {
        final RegExpMatch? m = value!.firstMatch(text);
        if (m == null) continue;
        raw = m.group(0)!;
      }
      result.add(FieldCandidate(
        rawText: raw.trim(),
        matchScore: score,
        ocrConfidence: inside.fold<double>(
                0, (double s, OcrWord word) => s + word.confidence) /
            inside.length,
        locator: 'region $region',
        box: BoundingBox.unionAll(inside.map((OcrWord word) => word.box)),
        lineIndex: line.index,
      ));
    }
    return result;
  }
}

/// Takes the first lines that look like a title: mostly letters and few
/// digits. Useful for store or company names at the top of receipts.
class HeaderLocator implements FieldLocator {
  /// Creates the locator.
  const HeaderLocator({this.maxLines = 3, this.score = 0.6});

  /// How many leading lines are considered.
  final int maxLines;

  /// Score of the first title-like line; later ones get less.
  final double score;

  @override
  List<FieldCandidate> locate(DocumentText document) {
    final List<FieldCandidate> result = <FieldCandidate>[];
    int rank = 0;
    for (final DocumentLine line in document.lines.take(maxLines)) {
      final String t = line.text;
      final int letters = RegExp(r'[A-Za-z؀-ۿ]').allMatches(t).length;
      final int digits = RegExp(r'\d').allMatches(t).length;
      if (letters < 3 || digits > letters * 0.3) continue;
      result.add(_candidate(
          document, line, 0, t.length, score * (1 - 0.15 * rank), 'header'));
      rank++;
    }
    return result;
  }
}
