# smart_document_capture_tesseract

Offline [Tesseract](https://github.com/tesseract-ocr/tesseract) engine for
[`smart_document_capture`](https://pub.dev/packages/smart_document_capture),
built on [`flutter_tesseract_ocr`](https://pub.dev/packages/flutter_tesseract_ocr).

* Works without internet, on Android and iOS.
* Supports Persian (`fas`), English (`eng`) and every other Tesseract
  language.
* Reads Tesseract's hOCR output, so every word has a **box** and a
  **confidence** — used by the core package for field scores and for drawing
  boxes in the review widget.

## Setup

1. Add the packages:

   ```yaml
   dependencies:
     smart_document_capture: ^0.1.0
     smart_document_capture_tesseract: ^0.1.0
   ```

2. Download the trained data of your languages (for example `fas.traineddata`
   and `eng.traineddata` from
   [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) or the more
   accurate [tessdata_best](https://github.com/tesseract-ocr/tessdata_best))
   into `assets/tessdata/`, and list them in `assets/tessdata_config.json`:

   ```json
   { "files": ["fas.traineddata", "eng.traineddata"] }
   ```

3. Declare the assets in your app's `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - assets/tessdata_config.json
       - assets/tessdata/
   ```

## Usage

```dart
final capture = DocumentCapture(
  engine: TesseractOcrEngine(),
  options: const OcrOptions(languages: ['fas', 'eng']),
);

final result = await capture.process(
  DocumentImage.file(photo.path),
  ReceiptSchema.persian,
);
```

`TesseractOcrEngine(args: {...})` sets Tesseract variables. The default page
segmentation mode `psm: 4` suits receipts; use `3` for full pages. Per-call
variables can be passed in `OcrOptions.extra`.

Only `DocumentImage.file` is supported; save in-memory images to a file
first.

## Tips for better results

* Photograph the document flat, well lit and filling the frame.
* Crop and straighten the image before OCR (for example with a document
  scanner package).
* `tessdata_best` is slower but noticeably better for Persian.

## Parsing hOCR yourself

`HocrParser.parse(hocr)` turns any Tesseract hOCR output into an `OcrResult`,
for example from a server-side Tesseract.

## License

MIT
