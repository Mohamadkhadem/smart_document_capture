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
}
