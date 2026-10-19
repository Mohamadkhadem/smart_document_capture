import '../geometry/bounding_box.dart';

/// A single recognized word.
class OcrWord {
  /// Creates a word.
  const OcrWord({required this.text, this.box, this.confidence = 1});

  /// Creates a word from JSON produced by [toJson].
  factory OcrWord.fromJson(Map<String, dynamic> json) => OcrWord(
        text: json['text'] as String,
        box: json['box'] == null
            ? null
            : BoundingBox.fromJson(json['box'] as Map<String, dynamic>),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
      );

  /// Recognized text.
  final String text;

  /// Location of the word in the image, when the engine reports it.
  final BoundingBox? box;

  /// Engine confidence between 0 and 1.
  final double confidence;

  /// Serializes the word.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        if (box != null) 'box': box!.toJson(),
        'confidence': confidence,
      };

  @override
  String toString() => 'OcrWord($text, $confidence)';
}

/// A line of words in reading order.
class OcrLine {
  /// Creates a line.
  ///
  /// [box] defaults to the union of the word boxes.
  OcrLine({required this.words, BoundingBox? box})
      : box = box ?? BoundingBox.unionAll(words.map((OcrWord w) => w.box));

  /// Creates a line from plain [text], splitting it on whitespace.
  ///
  /// Useful for tests and engines that only return text.
  factory OcrLine.fromText(String text,
      {double confidence = 1, BoundingBox? box}) {
    return OcrLine(
      words: <OcrWord>[
        for (final String part in text.trim().split(RegExp(r'\s+')))
          if (part.isNotEmpty) OcrWord(text: part, confidence: confidence),
      ],
      box: box,
    );
  }

  /// Creates a line from JSON produced by [toJson].
  factory OcrLine.fromJson(Map<String, dynamic> json) => OcrLine(
        words: <OcrWord>[
          for (final Object? w in json['words'] as List<Object?>)
            OcrWord.fromJson(w! as Map<String, dynamic>),
        ],
        box: json['box'] == null
            ? null
            : BoundingBox.fromJson(json['box'] as Map<String, dynamic>),
      );

  /// Words of the line in reading order.
  final List<OcrWord> words;

  /// Location of the line in the image, when known.
  final BoundingBox? box;

  /// Words joined by single spaces.
  String get text => words.map((OcrWord w) => w.text).join(' ');

  /// Average word confidence, or 0 for an empty line.
  double get confidence => words.isEmpty
      ? 0
      : words.fold<double>(0, (double s, OcrWord w) => s + w.confidence) /
          words.length;

  /// Serializes the line.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'words': <Map<String, dynamic>>[
          for (final OcrWord w in words) w.toJson(),
        ],
        if (box != null) 'box': box!.toJson(),
      };

  @override
  String toString() => 'OcrLine($text)';
}

/// A block (paragraph or text area) of lines.
class OcrBlock {
  /// Creates a block.
  OcrBlock({required this.lines, BoundingBox? box})
      : box = box ?? BoundingBox.unionAll(lines.map((OcrLine l) => l.box));

  /// Creates a block from JSON produced by [toJson].
  factory OcrBlock.fromJson(Map<String, dynamic> json) => OcrBlock(
        lines: <OcrLine>[
          for (final Object? l in json['lines'] as List<Object?>)
            OcrLine.fromJson(l! as Map<String, dynamic>),
        ],
        box: json['box'] == null
            ? null
            : BoundingBox.fromJson(json['box'] as Map<String, dynamic>),
      );

  /// Lines of the block in reading order.
  final List<OcrLine> lines;

  /// Location of the block in the image, when known.
  final BoundingBox? box;

  /// Lines joined by new lines.
  String get text => lines.map((OcrLine l) => l.text).join('\n');

  /// Serializes the block.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'lines': <Map<String, dynamic>>[
          for (final OcrLine l in lines) l.toJson(),
        ],
        if (box != null) 'box': box!.toJson(),
      };
}

/// Everything an [OcrEngine] recognized in one image.
class OcrResult {
  /// Creates a result.
  const OcrResult({
    required this.blocks,
    this.imageWidth,
    this.imageHeight,
    this.engine = 'unknown',
  });

  /// Creates a single-block result from plain text lines.
  factory OcrResult.fromText(String text,
      {double confidence = 1, String engine = 'text'}) {
    return OcrResult(
      engine: engine,
      blocks: <OcrBlock>[
        OcrBlock(lines: <OcrLine>[
          for (final String line in text.split('\n'))
            if (line.trim().isNotEmpty)
              OcrLine.fromText(line, confidence: confidence),
        ]),
      ],
    );
  }

  /// Creates a result from JSON produced by [toJson].
  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
        blocks: <OcrBlock>[
          for (final Object? b in json['blocks'] as List<Object?>)
            OcrBlock.fromJson(b! as Map<String, dynamic>),
        ],
        imageWidth: (json['imageWidth'] as num?)?.toDouble(),
        imageHeight: (json['imageHeight'] as num?)?.toDouble(),
        engine: json['engine'] as String? ?? 'unknown',
      );

  /// An empty result.
  static const OcrResult empty = OcrResult(blocks: <OcrBlock>[]);

  /// Recognized blocks in reading order.
  final List<OcrBlock> blocks;

  /// Width of the analyzed image in pixels, when known.
  final double? imageWidth;

  /// Height of the analyzed image in pixels, when known.
  final double? imageHeight;

  /// Name of the engine that produced the result.
  final String engine;

  /// All lines of all blocks in reading order.
  List<OcrLine> get lines =>
      <OcrLine>[for (final OcrBlock b in blocks) ...b.lines];

  /// All words of the result in reading order.
  List<OcrWord> get words =>
      <OcrWord>[for (final OcrLine l in lines) ...l.words];

  /// The whole recognized text, one line per row.
  String get text => lines.map((OcrLine l) => l.text).join('\n');

  /// Serializes the result.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'engine': engine,
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
        'blocks': <Map<String, dynamic>>[
          for (final OcrBlock b in blocks) b.toJson(),
        ],
      };
}
