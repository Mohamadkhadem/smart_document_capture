/// Texts used by `DocumentReviewView`.
class ReviewStrings {
  /// Creates a set of texts.
  const ReviewStrings({
    required this.confidence,
    required this.missing,
    required this.invalid,
    required this.required,
    required this.alternatives,
    required this.submit,
    required this.corrected,
  });

  /// Persian texts (default).
  static const ReviewStrings persian = ReviewStrings(
    confidence: 'اطمینان',
    missing: 'پیدا نشد',
    invalid: 'مقدار معتبر نیست',
    required: 'الزامی',
    alternatives: 'گزینه‌های دیگر',
    submit: 'تأیید',
    corrected: 'اصلاح شده',
  );

  /// English texts.
  static const ReviewStrings english = ReviewStrings(
    confidence: 'Confidence',
    missing: 'Not found',
    invalid: 'Invalid value',
    required: 'Required',
    alternatives: 'Other options',
    submit: 'Confirm',
    corrected: 'Corrected',
  );

  /// Label of the confidence badge.
  final String confidence;

  /// Shown for fields that were not found.
  final String missing;

  /// Shown under fields whose text failed validation.
  final String invalid;

  /// Marks required fields.
  final String required;

  /// Title of the alternative values.
  final String alternatives;

  /// Text of the submit button.
  final String submit;

  /// Shown instead of the confidence for fields edited by the user.
  final String corrected;
}
