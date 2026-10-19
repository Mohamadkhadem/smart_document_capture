import 'package:flutter/foundation.dart';

import '../extraction/extraction_result.dart';

/// Holds the [ExtractionResult] being reviewed and the selected field.
class DocumentReviewController extends ChangeNotifier {
  /// Creates a controller for [result].
  DocumentReviewController(ExtractionResult result) : _result = result;

  ExtractionResult _result;
  String? _selectedKey;

  /// The current result, including corrections.
  ExtractionResult get result => _result;

  /// Replaces the result, e.g. after processing another image.
  set result(ExtractionResult value) {
    _result = value;
    if (_selectedKey != null && !value.fields.containsKey(_selectedKey)) {
      _selectedKey = null;
    }
    notifyListeners();
  }

  /// Key of the highlighted field.
  String? get selectedKey => _selectedKey;

  /// Highlights the field with [key], or nothing for `null`.
  void select(String? key) {
    if (key == _selectedKey) return;
    _selectedKey = key;
    notifyListeners();
  }

  /// Records [text] as the value of field [key], unless it is unchanged.
  void correct(String key, String text) {
    final String? current = _result[key]?.rawText;
    if ((current ?? '') == text.trim()) return;
    _result = _result.correct(key, text);
    notifyListeners();
  }
}
