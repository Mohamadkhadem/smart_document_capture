import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:persian_calendar_kit/persian_calendar_kit.dart';
import 'package:smart_document_capture/smart_document_capture.dart';

const String receipt = '''
فروشگاه زنجیره‌ای افق کوروش
شعبه ونک
تاریخ: ۱۴۰۴/۰۷/۲۷   ساعت: ۱۴:۳۵
شماره فاکتور: ۸۷۴۵۲
شیر پرچرب ۱ لیتری    ۴۵,۰۰۰
نان تست    ۳۸,۰۰۰
جمع اقلام: ۸۳,۰۰۰
تخفیف: ۵,۰۰۰
مبلغ قابل پرداخت: ۷۸,۰۰۰ ریال
شماره کارت: ۶۰۳۷-۹۹**-****-۷۸۹۳
شماره پیگیری: ۱۲۳۴۵۶
''';

void main() {
  group('receipt schema', () {
    final ExtractionResult result = const DocumentExtractor().extract(
        OcrResult.fromText(receipt, confidence: 0.95), ReceiptSchema.persian);

    test('extracts every field', () {
      expect(result['storeName']!.value, 'فروشگاه زنجیره ای افق کوروش');
      expect(result['date']!.value, JalaliDate(1404, 7, 27));
      expect(result['time']!.value, '14:35');
      expect(result['total']!.value, 78000);
      expect(result['invoiceNumber']!.value, '87452');
      expect(result['trackingNumber']!.value, '123456');
      expect(result['cardNumber']!.value, '603799******7893');
      expect(result.isComplete, isTrue);
    });

    test('total keeps the subtotal as an alternative', () {
      final ExtractedField total = result['total']!;
      expect(total.rawText, '78,000 ریال');
      expect(total.alternatives.map((FieldAlternative a) => a.value),
          contains(83000));
      expect(total.level(), ConfidenceLevel.high);
    });

    test('serializes to json', () {
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>;
      expect(json['schema'], 'receipt');
      expect(json['fields']['date']['value'], '1404/07/27');
      expect(json['fields']['total']['value'], 78000);
      expect(json['fields']['total']['source'], 'ocr');
    });
  });

  test('missing and invalid fields', () {
    final ExtractionResult r = const DocumentExtractor().extract(
        OcrResult.fromText('تاریخ: ۱۴۰۴/۱۳/۴۰\nسلام'), ReceiptSchema.persian);
    expect(r['total']!.isMissing, isTrue);
    expect(r['date']!.isValid, isFalse);
    expect(r['date']!.value, isNull);
    expect(r['date']!.rawText, '1404/13/40');
    expect(r.isComplete, isFalse);
    expect(r.fieldsToReview().map((ExtractedField f) => f.key),
        containsAll(<String>['date', 'total']));
  });

  test('confidence follows OCR confidence', () {
    ExtractedField total(double c) => const DocumentExtractor().extract(
        OcrResult.fromText('جمع کل: ۱۲۰,۰۰۰', confidence: c),
        ReceiptSchema.persian)['total']!;
    expect(total(0.98).level(), ConfidenceLevel.high);
    expect(total(0.7).level(), ConfidenceLevel.medium);
    expect(total(0.4).level(), ConfidenceLevel.low);
  });

  test('corrections are validated and recorded', () {
    final ExtractionResult r = const DocumentExtractor()
        .extract(OcrResult.fromText('جمع کل: ۱۲۰,۰۰۰'), ReceiptSchema.persian);
    final ExtractionResult fixed =
        r.correct('date', '1404/08/01').correct('total', 'abc');
    expect(fixed['date']!.value, JalaliDate(1404, 8, 1));
    expect(fixed['date']!.source, FieldSource.user);
    expect(fixed['date']!.confidence, 1);
    expect(fixed['total']!.isValid, isFalse);
    expect(fixed.corrections.map((FieldCorrection c) => c.key),
        <String>['date', 'total']);
    expect(fixed.corrections.first.previousText, isNull);
    expect(r['date']!.isMissing, isTrue); // original unchanged
    expect(() => r.correct('nope', 'x'), throwsArgumentError);
  });

  test('keyword value on the next line and before the keyword', () {
    final DocumentText doc =
        DocumentText(OcrResult.fromText('شماره پیگیری\n۹۸۷۶۵۴\n۵۰۰۰ :مبلغ'));
    final List<FieldCandidate> below =
        KeywordLocator(<String>['شماره پیگیری'], value: RegExp(r'\d+'))
            .locate(doc);
    expect(below.single.rawText, '987654');
    expect(below.single.matchScore, 0.8);
    final List<FieldCandidate> before =
        KeywordLocator(<String>['مبلغ'], value: RegExp(r'\d+')).locate(doc);
    expect(before.single.rawText, '5000');
  });

  test('boxes and confidence come from the matched words', () {
    final OcrResult ocr = OcrResult(
      imageWidth: 1000,
      imageHeight: 1000,
      blocks: <OcrBlock>[
        OcrBlock(lines: <OcrLine>[
          OcrLine(words: const <OcrWord>[
            OcrWord(
                text: 'جمع',
                box: BoundingBox.fromLTRB(800, 100, 900, 130),
                confidence: 0.9),
            OcrWord(
                text: 'کل:',
                box: BoundingBox.fromLTRB(740, 100, 790, 130),
                confidence: 0.9),
            OcrWord(
                text: '۵۰,۰۰۰',
                box: BoundingBox.fromLTRB(500, 100, 600, 130),
                confidence: 0.6),
          ]),
        ]),
      ],
    );
    final ExtractedField total =
        const DocumentExtractor().extract(ocr, ReceiptSchema.persian)['total']!;
    expect(total.box, const BoundingBox.fromLTRB(500, 100, 600, 130));
    expect(total.confidence, closeTo(0.6 * 0.95, 0.06));

    final List<FieldCandidate> region =
        const RegionLocator(BoundingBox.fromLTRB(0.4, 0, 0.65, 0.2))
            .locate(DocumentText(ocr));
    expect(region.single.rawText, '50,000');
  });

  test('key/value schema infers types', () {
    const String form = '''
نام: علی
نام خانوادگی: محمدی
کد ملی: ۰۴۹۹۳۷۰۸۹۹
تاریخ تولد: ۱۳۷۰/۰۵/۱۲
موبایل: ۰۹۱۲۱۲۳۴۵۶۷
شبا: IR062960000000100324200001
مبلغ: ۲,۵۰۰,۰۰۰
''';
    final ExtractionResult r = const DocumentExtractor()
        .extract(OcrResult.fromText(form), const KeyValueSchema());
    expect(r.fields.keys, <String>[
      'نام',
      'نام_خانوادگی',
      'کد_ملی',
      'تاریخ_تولد',
      'موبایل',
      'شبا',
      'مبلغ',
    ]);
    expect(r['نام']!.value, 'علی');
    expect(r['کد_ملی']!.definition.type, FieldType.nationalCode);
    expect(r['تاریخ_تولد']!.value, JalaliDate(1370, 5, 12));
    expect(r['موبایل']!.definition.type, FieldType.phone);
    expect(r['شبا']!.definition.type, FieldType.sheba);
    expect(r['مبلغ']!.value, 2500000);
    // Validated values are trusted, plain text needs a glance.
    expect(r['کد_ملی']!.level(), ConfidenceLevel.high);
    expect(r['نام']!.confidence, lessThan(r['کد_ملی']!.confidence));
  });

  test('pipeline with FakeOcrEngine', () async {
    final FakeOcrEngine engine = FakeOcrEngine.text(receipt);
    final DocumentCapture capture = DocumentCapture(engine: engine);
    final ExtractionResult r = await capture.process(
        const DocumentImage.file('receipt.jpg'), ReceiptSchema.persian);
    expect(r['total']!.value, 78000);
    expect(r.ocr.engine, 'fake');
    expect(engine.calls.single.path, 'receipt.jpg');
  });

  test('ocr result json round trip', () {
    final OcrResult ocr = OcrResult.fromText('a b\nc');
    final OcrResult back = OcrResult.fromJson(
        jsonDecode(jsonEncode(ocr.toJson())) as Map<String, dynamic>);
    expect(back.text, 'a b\nc');
    expect(back.words.length, 3);
  });
}
