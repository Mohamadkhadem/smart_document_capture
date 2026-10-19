import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_document_capture/smart_document_capture.dart';

void main() {
  ExtractionResult extract() => const DocumentExtractor().extract(
      OcrResult.fromText('تاریخ: ۱۴۰۴/۰۷/۲۷\nجمع اقلام: ۸۳,۰۰۰\nجمع کل: ۷۸,۰۰۰',
          confidence: 0.95),
      ReceiptSchema.persian);

  Widget host(DocumentReviewController c,
          {ValueChanged<ExtractionResult>? onSubmit}) =>
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: DocumentReviewView(controller: c, onSubmit: onSubmit),
          ),
        ),
      );

  testWidgets('shows fields with confidence and missing markers',
      (WidgetTester tester) async {
    final DocumentReviewController c = DocumentReviewController(extract());
    await tester.pumpWidget(host(c));

    expect(find.text('مبلغ کل *'), findsOneWidget);
    expect(find.text('78,000'), findsOneWidget);
    expect(find.textContaining('اطمینان'), findsWidgets);
    expect(find.text('پیدا نشد'), findsWidgets); // e.g. tracking number
  });

  testWidgets('editing a field records a correction',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final DocumentReviewController c = DocumentReviewController(extract());
    ExtractionResult? submitted;
    await tester
        .pumpWidget(host(c, onSubmit: (ExtractionResult r) => submitted = r));

    final Finder total = find.descendant(
        of: find.byKey(const ValueKey<String>('field-total')),
        matching: find.byType(TextField));
    await tester.enterText(total, '۸۰,۰۰۰');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(c.result['total']!.value, 80000);
    expect(c.result['total']!.source, FieldSource.user);
    expect(find.text('اصلاح شده'), findsOneWidget);

    await tester.tap(find.text('تأیید'));
    expect(submitted?.corrections.single.key, 'total');
  });

  testWidgets('choosing an alternative replaces the value',
      (WidgetTester tester) async {
    final DocumentReviewController c = DocumentReviewController(extract());
    await tester.pumpWidget(host(c));

    await tester.tap(find.widgetWithText(ActionChip, '83,000'));
    await tester.pump();
    expect(c.result['total']!.value, 83000);
  });

  testWidgets('invalid text shows an error', (WidgetTester tester) async {
    final DocumentReviewController c = DocumentReviewController(extract());
    await tester.pumpWidget(host(c));
    c.correct('date', '1404/13/01');
    await tester.pump();
    expect(find.text('مقدار معتبر نیست'), findsOneWidget);
  });

  test('percent formatting', () {
    expect(ReviewStrings.persian.percent(0.574), '۵۷٪');
    expect(ReviewStrings.english.percent(0.9), '90%');
  });

  testWidgets('tapping a box on the image selects its field',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final OcrResult ocr = OcrResult(
      imageWidth: 400,
      imageHeight: 400,
      blocks: <OcrBlock>[
        OcrBlock(lines: <OcrLine>[
          OcrLine(words: const <OcrWord>[
            OcrWord(
                text: 'جمع',
                box: BoundingBox.fromLTRB(300, 100, 380, 130),
                confidence: 0.95),
            OcrWord(
                text: 'کل:',
                box: BoundingBox.fromLTRB(240, 100, 290, 130),
                confidence: 0.95),
            OcrWord(
                text: '۵۰,۰۰۰',
                box: BoundingBox.fromLTRB(100, 100, 200, 130),
                confidence: 0.95),
          ]),
        ]),
      ],
    );
    final DocumentReviewController c = DocumentReviewController(
        const DocumentExtractor().extract(ocr, ReceiptSchema.persian));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentReviewView(
          controller: c,
          image: MemoryImage(Uint8List.fromList(_transparentPng)),
        ),
      ),
    ));
    final Finder box = find.bySemanticsLabel('مبلغ کل');
    expect(box, findsOneWidget);
    await tester.tap(box);
    await tester.pump();
    expect(c.selectedKey, 'total');
  });
}

const List<int> _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
