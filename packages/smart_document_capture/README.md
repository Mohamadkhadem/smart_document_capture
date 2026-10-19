# smart_document_capture

Extract **structured data** from images of documents, receipts and forms —
with a **confidence score for every field**, a **manual review widget** and a
**pluggable OCR engine** layer.

* 🔌 **Engine independent**: implement one interface (`OcrEngine`) to use
  any OCR library. An offline Tesseract engine is available as
  [`smart_document_capture_tesseract`](https://pub.dev/packages/smart_document_capture_tesseract).
* 🧾 **Structured output**: describe a document as a `DocumentSchema` of
  fields; get typed values (`num`, `JalaliDate`, `String`) and JSON.
* 📊 **Confidence per field**: combines OCR confidence, how well the field
  was located and whether the value passed validation.
* ✍️ **Manual correction**: `DocumentReviewView` highlights doubtful fields,
  shows boxes on the image, offers alternatives and records every change.
* 🇮🇷 **Persian first**: Persian/Arabic digits and letters are normalized;
  validators for national code, bank card (Luhn), Sheba, mobile numbers and
  Jalali dates (via [`persian_calendar_kit`](https://pub.dev/packages/persian_calendar_kit)).

## Installation

```yaml
dependencies:
  smart_document_capture: ^0.1.0
  # an engine, e.g. offline Tesseract:
  smart_document_capture_tesseract: ^0.1.0
```

## Quick start

```dart
import 'package:smart_document_capture/smart_document_capture.dart';
import 'package:smart_document_capture_tesseract/smart_document_capture_tesseract.dart';

final capture = DocumentCapture(engine: TesseractOcrEngine());

final result = await capture.process(
  DocumentImage.file(photo.path),
  ReceiptSchema.persian,
);

result['total']?.value;        // 78000
result['date']?.value;         // JalaliDate 1404/07/27
result['total']?.confidence;   // 0.93
result.needsReview();          // true when a field is doubtful
result.toJson();               // structured JSON
```

## How it works

```
image ──► OcrEngine ──► OcrResult (blocks → lines → words, boxes, confidence)
                              │
                 DocumentSchema (fields → locators + validator)
                              │
                     DocumentExtractor
                              │
          ExtractionResult (value, raw text, confidence, box,
                            alternatives, corrections) ──► review / JSON
```

1. **Locators** find candidate texts for a field:
   * `KeywordLocator(['جمع کل', 'total'], value: ValuePatterns.amount)` —
     a label and the value next to it (same line, before it, or next line).
   * `PatternLocator(ValuePatterns.date)` — any match in the document.
   * `RegionLocator(BoundingBox.fromLTRB(0.5, 0, 1, 0.2))` — the words in a
     part of the page (fractions of the image size).
   * `HeaderLocator()` — title-like first lines, e.g. a store name.
2. **Validators** parse and check each candidate: `AmountValidator`,
   `JalaliDateValidator`, `TimeValidator`, `NationalCodeValidator`,
   `BankCardValidator`, `ShebaValidator`, `MobileNumberValidator`,
   `NumberValidator`, `RegexValidator`, `TextValidator`.
3. **Scoring** (`DefaultConfidenceModel`):
   `ocrConfidence × matchScore × validationFactor + agreementBonus`.
   The best candidate wins; the others are kept as `alternatives`.

## Ready-made schemas

| Schema | Fields |
|---|---|
| `ReceiptSchema.persian` | `storeName`, `date`*, `time`, `total`*, `invoiceNumber`, `trackingNumber`, `cardNumber` |
| `KeyValueSchema()` | every `label: value` line, with the value type inferred |

## Your own schema

```dart
final invoice = DocumentSchema(
  id: 'invoice',
  name: 'فاکتور',
  fields: [
    FieldDefinition(
      key: 'number',
      label: 'شماره فاکتور',
      type: FieldType.identifier,
      required: true,
      locators: [KeywordLocator(['شماره فاکتور'], value: RegExp(r'\d+'))],
      validator: RegexValidator(RegExp(r'\d+')),
    ),
    FieldDefinition(
      key: 'buyerCode',
      label: 'کد ملی خریدار',
      type: FieldType.nationalCode,
      locators: [
        KeywordLocator(['کد ملی'], value: ValuePatterns.nationalCode),
      ],
      validator: const NationalCodeValidator(),
    ),
  ],
);
```

## Manual review

```dart
final controller = DocumentReviewController(result);

DocumentReviewView(
  controller: controller,
  image: FileImage(File(photo.path)), // draws the field boxes
  onSubmit: (reviewed) => save(reviewed.toJson()),
);
```

Fields below the confidence threshold or failing validation are
highlighted. Edits are validated, get confidence `1` and are listed in
`result.corrections`. Texts are Persian by default
(`strings: ReviewStrings.english` for English).

Corrections work without the widget too:

```dart
final fixed = result.correct('total', '80,000');
```

## Writing an engine

```dart
class MyEngine implements OcrEngine {
  @override
  String get name => 'my_engine';

  @override
  Future<OcrResult> recognize(DocumentImage image,
      {OcrOptions options = const OcrOptions()}) async {
    // call your OCR and map its output:
    return OcrResult(imageWidth: w, imageHeight: h, blocks: [...]);
  }

  @override
  Future<void> dispose() async {}
}
```

`FakeOcrEngine.text('...')` returns prepared text and is handy for tests and
for designing schemas.

## License

MIT
