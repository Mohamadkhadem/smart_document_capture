## 0.1.0

* Initial release.
* `OcrEngine` interface, `OcrResult` model and `FakeOcrEngine`.
* `DocumentSchema`, `FieldDefinition` and locators: keyword, pattern,
  region and header.
* Per-field confidence (`DefaultConfidenceModel`), alternatives and
  confidence levels.
* Validators: text, regex, number, amount, time, Jalali date, Iranian
  national code, bank card, Sheba and mobile number.
* `ReceiptSchema.persian` and `KeyValueSchema`.
* `ExtractionResult` with corrections and JSON output.
* `DocumentReviewView` for manual review and correction.
