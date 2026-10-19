import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_document_capture/smart_document_capture.dart';

void main() => runApp(const DemoApp());

const String _receipt = '''
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
شماره پیگیری: ۱۲۳۴۵۶''';

const String _form = '''
نام: علی
نام خانوادگی: محمدی
کد ملی: ۰۴۹۹۳۷۰۸۹۹
تاریخ تولد: ۱۳۷۰/۰۵/۱۲
موبایل: ۰۹۱۲۱۲۳۴۵۶۷
شبا: IR062960000000100324200001''';

/// The demo application.
class DemoApp extends StatelessWidget {
  /// Creates the app.
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Document Capture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      builder: (BuildContext context, Widget? child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const InputPage(),
    );
  }
}

/// Lets the user type or pick OCR text and a schema.
class InputPage extends StatefulWidget {
  /// Creates the page.
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController _text = TextEditingController(text: _receipt);
  bool _receiptSchema = true;
  double _ocrConfidence = 0.95;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    // A real app would use an engine such as TesseractOcrEngine and a photo.
    final DocumentCapture capture = DocumentCapture(
      engine: FakeOcrEngine.text(_text.text, confidence: _ocrConfidence),
    );
    final ExtractionResult result = await capture.process(
      const DocumentImage.file('demo.jpg'),
      _receiptSchema ? ReceiptSchema.persian : const KeyValueSchema(),
    );
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReviewPage(result: result),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استخراج اطلاعات از سند')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text('رسید خرید')),
              ButtonSegment<bool>(value: false, label: Text('فرم کلید/مقدار')),
            ],
            selected: <bool>{_receiptSchema},
            onSelectionChanged: (Set<bool> s) => setState(() {
              _receiptSchema = s.first;
              _text.text = _receiptSchema ? _receipt : _form;
            }),
          ),
          const SizedBox(height: 16),
          Text('متن خوانده‌شده توسط OCR',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLines: 12,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text(
              'اطمینان شبیه‌سازی‌شده‌ی OCR: ${(_ocrConfidence * 100).round()}٪'),
          Slider(
            value: _ocrConfidence,
            min: 0.3,
            max: 1,
            divisions: 14,
            onChanged: (double v) => setState(() => _ocrConfidence = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _extract,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('استخراج'),
          ),
        ],
      ),
    );
  }
}

/// Shows the extracted fields for review.
class ReviewPage extends StatefulWidget {
  /// Creates the page.
  const ReviewPage({super.key, required this.result});

  /// Result to review.
  final ExtractionResult result;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final DocumentReviewController _controller =
      DocumentReviewController(widget.result);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showJson(ExtractionResult result) {
    final String json =
        const JsonEncoder.withIndent('  ').convert(result.toJson());
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('خروجی JSON'),
        content: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازبینی'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, _) {
              final ExtractionResult r = _controller.result;
              final int n = r.fieldsToReview().length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(n == 0
                    ? 'همه‌ی فیلدها قابل اطمینان‌اند'
                    : '$n فیلد نیاز به بررسی دارد'),
              );
            },
          ),
        ),
      ),
      body: DocumentReviewView(controller: _controller, onSubmit: _showJson),
    );
  }
}
