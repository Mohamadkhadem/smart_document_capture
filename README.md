# Smart Document Capture

Extract structured data from document, receipt and form images in Flutter,
with per-field confidence, manual review and pluggable OCR engines.

| Package | Description |
|---|---|
| [`smart_document_capture`](packages/smart_document_capture) | Core: models, schemas, locators, validators, confidence scoring and the review widget |
| [`smart_document_capture_tesseract`](packages/smart_document_capture_tesseract) | Offline Tesseract engine (Persian and English) |

## Development

```bash
cd packages/smart_document_capture
flutter test
cd example
flutter run -d chrome
```

The Tesseract package uses the local core package through
`pubspec_overrides.yaml`.

## Roadmap

* 0.1 — offline (Tesseract), receipts and key/value forms ✅
* Next — online engines (Google Cloud Vision, Azure Document Intelligence),
  Iranian national card and bank card schemas, document edge detection.

## License

MIT
