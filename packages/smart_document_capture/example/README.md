# smart_document_capture example

Paste OCR text (or use the sample receipt and form), choose a schema and see
the extracted fields with their confidence in `DocumentReviewView`. The
example uses `FakeOcrEngine`, so it runs on every platform including the web;
swap in `TesseractOcrEngine` and a photo for real recognition.

```bash
flutter run -d chrome
```
