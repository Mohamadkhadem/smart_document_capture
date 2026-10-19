import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:persian_calendar_kit/persian_calendar_kit.dart'
    show PersianDigits;
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

enum _Mode { photo, receiptText, form }

class _InputPageState extends State<InputPage> {
  final TextEditingController _text = TextEditingController(text: _receipt);
  _Mode _mode = _Mode.photo;
  double _ocrConfidence = 0.95;

  static const AssetImage _photo = AssetImage('assets/receipt.jpg');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    // A real app would use an engine such as TesseractOcrEngine on a photo.
    // Here the photo mode replays a recorded OCR result with word boxes.
    final OcrEngine engine;
    if (_mode == _Mode.photo) {
      final String json = await DefaultAssetBundle.of(context)
          .loadString('assets/receipt_ocr.json');
      engine = FakeOcrEngine(
          OcrResult.fromJson(jsonDecode(json) as Map<String, dynamic>));
    } else {
      engine = FakeOcrEngine.text(_text.text, confidence: _ocrConfidence);
    }
    final DocumentCapture capture = DocumentCapture(engine: engine);
    final ExtractionResult result = await capture.process(
      const DocumentImage.file('receipt.jpg'),
      _mode == _Mode.form ? const KeyValueSchema() : ReceiptSchema.persian,
    );
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReviewPage(
        result: result,
        image: _mode == _Mode.photo ? _photo : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استخراج اطلاعات از سند')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<_Mode>(
            segments: const <ButtonSegment<_Mode>>[
              ButtonSegment<_Mode>(value: _Mode.photo, label: Text('عکس رسید')),
              ButtonSegment<_Mode>(
                  value: _Mode.receiptText, label: Text('متن رسید')),
              ButtonSegment<_Mode>(value: _Mode.form, label: Text('فرم')),
            ],
            selected: <_Mode>{_mode},
            onSelectionChanged: (Set<_Mode> s) => setState(() {
              _mode = s.first;
              if (_mode != _Mode.photo) {
                _text.text = _mode == _Mode.form ? _form : _receipt;
              }
            }),
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.photo) ...<Widget>[
            Text('عکس سند', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: const Image(image: _photo, fit: BoxFit.contain),
              ),
            ),
          ] else ...<Widget>[
            Text('متن خوانده‌شده توسط OCR',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLines: 12,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text('اطمینان شبیه‌سازی‌شده‌ی OCR: '
                '${PersianDigits.toPersian((_ocrConfidence * 100).round())}٪'),
            Slider(
              value: _ocrConfidence,
              min: 0.3,
              max: 1,
              divisions: 14,
              onChanged: (double v) => setState(() => _ocrConfidence = v),
            ),
          ],
          const SizedBox(height: 16),
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
  const ReviewPage({super.key, required this.result, this.image});

  /// Result to review.
  final ExtractionResult result;

  /// The analyzed photo, when there is one.
  final ImageProvider? image;

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
                    : '${PersianDigits.toPersian(n)} فیلد نیاز به بررسی دارد'),
              );
            },
          ),
        ),
      ),
      body: DocumentReviewView(
        controller: _controller,
        image: widget.image,
        onSubmit: _showJson,
      ),
    );
  }
}
