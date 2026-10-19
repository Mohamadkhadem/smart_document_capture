# smart_document_capture example

Three modes:

* **Receipt photo** — a sample receipt image with a recorded Tesseract-style
  OCR result (word boxes and confidence). The review view draws colored boxes
  on the photo.
* **Receipt text** — type or paste OCR text and set a simulated OCR
  confidence.
* **Form** — `label: value` lines extracted with `KeyValueSchema`.

The example uses `FakeOcrEngine`, so it runs on every platform including the
web; swap in `TesseractOcrEngine` and a real photo for recognition.

```bash
flutter run -d chrome
```
