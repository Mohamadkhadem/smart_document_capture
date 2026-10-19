import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_document_capture/smart_document_capture.dart';
import 'package:smart_document_capture_tesseract/smart_document_capture_tesseract.dart';

const String hocr = '''
<?xml version="1.0" encoding="UTF-8"?>
<html><body>
 <div class='ocr_page' id='page_1' title='image "receipt.jpg"; bbox 0 0 800 1200; ppageno 0'>
  <div class='ocr_carea' id='block_1_1' title="bbox 100 40 700 80">
   <p class='ocr_par' id='par_1_1' lang='fas' dir='rtl' title="bbox 100 40 700 80">
    <span class='ocr_header' id='line_1_1' title="bbox 100 40 700 80; baseline 0 -8; x_size 40">
     <span class='ocrx_word' id='word_1_1' title='bbox 520 40 700 80; x_wconf 93'>فروشگاه</span>
     <span class='ocrx_word' id='word_1_2' title='bbox 100 40 500 80; x_wconf 88'><strong>کوروش</strong></span>
    </span>
   </p>
  </div>
  <div class='ocr_carea' id='block_1_2' title="bbox 80 900 720 960">
   <p class='ocr_par' id='par_1_2' lang='fas' dir='rtl' title="bbox 80 900 720 960">
    <span class='ocr_line' id='line_1_2' title="bbox 80 900 720 930">
     <span class='ocrx_word' id='word_1_3' title='bbox 640 900 720 930; x_wconf 95'>جمع</span>
     <span class='ocrx_word' id='word_1_4' title='bbox 580 900 630 930; x_wconf 94'>کل:</span>
     <span class='ocrx_word' id='word_1_5' title='bbox 80 900 260 930; x_wconf 71'>۷۸,۰۰۰</span>
     <span class='ocrx_word' id='word_1_6' title='bbox 270 900 300 930; x_wconf 0'> </span>
    </span>
    <span class='ocr_line' id='line_1_3' title="bbox 80 935 720 960">
     <span class='ocrx_word' id='word_1_7' title='bbox 80 935 720 960; x_wconf 90'>A&amp;B &lt;ok&gt;</span>
    </span>
   </p>
  </div>
 </div>
</body></html>
''';

void main() {
  test('parses hOCR into blocks, lines and words', () {
    final OcrResult r = HocrParser.parse(hocr);
    expect(r.engine, 'tesseract');
    expect(r.imageWidth, 800);
    expect(r.imageHeight, 1200);
    expect(r.blocks.length, 2);
    expect(r.lines.map((OcrLine l) => l.text),
        <String>['فروشگاه کوروش', 'جمع کل: ۷۸,۰۰۰', 'A&B <ok>']);
    final OcrWord amount = r.lines[1].words[2];
    expect(amount.confidence, closeTo(0.71, 1e-9));
    expect(amount.box, const BoundingBox.fromLTRB(80, 900, 260, 930));
    expect(r.lines[1].box, const BoundingBox.fromLTRB(80, 900, 720, 930));
  });

  test('empty hOCR gives an empty result', () {
    expect(HocrParser.parse('').blocks, isEmpty);
  });

  test('engine passes languages and args, then extracts fields', () async {
    late String gotPath;
    late String gotLanguage;
    late Map<String, String> gotArgs;
    final TesseractOcrEngine engine = TesseractOcrEngine(
      recognizer: (String path, String language, Map<String, String> args) async {
        gotPath = path;
        gotLanguage = language;
        gotArgs = args;
        return hocr;
      },
    );
    final DocumentCapture capture = DocumentCapture(
      engine: engine,
      options: const OcrOptions(
          languages: <String>['fas', 'eng'],
          extra: <String, Object?>{'psm': 6}),
    );
    final ExtractionResult r = await capture.process(
        const DocumentImage.file('/tmp/receipt.jpg'), ReceiptSchema.persian);

    expect(gotPath, '/tmp/receipt.jpg');
    expect(gotLanguage, 'fas+eng');
    expect(gotArgs['psm'], '6');
    expect(gotArgs['preserve_interword_spaces'], '1');
    expect(r['total']!.value, 78000);
    expect(r['total']!.box, const BoundingBox.fromLTRB(80, 900, 260, 930));
    expect(r['total']!.confidence, lessThan(0.85)); // weak OCR on the amount
    expect(r['storeName']!.value, 'فروشگاه کوروش');
  });

  test('bytes images and engine errors become OcrException', () async {
    final TesseractOcrEngine engine = TesseractOcrEngine(
        recognizer: (_, __, ___) async => throw StateError('boom'));
    await expectLater(
        engine.recognize(DocumentImage.bytes(Uint8List(0))),
        throwsA(isA<OcrException>()));
    await expectLater(engine.recognize(const DocumentImage.file('x.jpg')),
        throwsA(isA<OcrException>()
            .having((OcrException e) => e.cause, 'cause', isA<StateError>())));
  });
}
