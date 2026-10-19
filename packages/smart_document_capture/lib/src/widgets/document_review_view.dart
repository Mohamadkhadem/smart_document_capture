import 'package:flutter/material.dart';

import '../extraction/confidence.dart';
import '../extraction/extracted_field.dart';
import '../extraction/extraction_result.dart';
import '../extraction/field_definition.dart';
import '../geometry/bounding_box.dart';
import 'document_review_controller.dart';
import 'review_strings.dart';

/// Colors of the confidence levels.
class ConfidenceColors {
  /// Creates the colors.
  const ConfidenceColors({
    this.high = const Color(0xFF2E7D32),
    this.medium = const Color(0xFFF9A825),
    this.low = const Color(0xFFC62828),
    this.user = const Color(0xFF1565C0),
  });

  /// Color of [ConfidenceLevel.high].
  final Color high;

  /// Color of [ConfidenceLevel.medium].
  final Color medium;

  /// Color of [ConfidenceLevel.low] and invalid fields.
  final Color low;

  /// Color of fields corrected by the user.
  final Color user;

  /// Color for [field].
  Color of(ExtractedField field, ConfidenceThresholds thresholds) {
    if (field.source == FieldSource.user) return field.isValid ? user : low;
    if (field.isMissing || !field.isValid) return low;
    return switch (field.level(thresholds)) {
      ConfidenceLevel.high => high,
      ConfidenceLevel.medium => medium,
      ConfidenceLevel.low => low,
    };
  }
}

/// Shows the document image with the field boxes and an editable list of
/// fields with their confidence.
///
/// Low confidence and invalid fields are highlighted; editing a field
/// records a correction in the controller's [ExtractionResult]. Tapping a
/// box selects its field and the other way round.
class DocumentReviewView extends StatefulWidget {
  /// Creates the view.
  const DocumentReviewView({
    super.key,
    required this.controller,
    this.image,
    this.strings = ReviewStrings.persian,
    this.thresholds = const ConfidenceThresholds(),
    this.colors = const ConfidenceColors(),
    this.onSubmit,
    this.showImage = true,
    this.imageMaxHeight = 360,
    this.fieldBuilder,
  });

  /// Holds the result and the selection.
  final DocumentReviewController controller;

  /// The analyzed image. Boxes are drawn when the OCR result has the image
  /// size and word boxes.
  final ImageProvider? image;

  /// Texts of the view.
  final ReviewStrings strings;

  /// Limits of the confidence levels.
  final ConfidenceThresholds thresholds;

  /// Colors of the confidence levels.
  final ConfidenceColors colors;

  /// Called with the final result when the submit button is pressed. The
  /// button is hidden when `null`.
  final ValueChanged<ExtractionResult>? onSubmit;

  /// Whether the image is shown (when given).
  final bool showImage;

  /// Maximum height of the image in the stacked (narrow) layout.
  final double imageMaxHeight;

  /// Replaces the default editor of a field. Return `null` to keep it.
  final Widget? Function(BuildContext context, ExtractedField field,
      DocumentReviewController controller)? fieldBuilder;

  @override
  State<DocumentReviewView> createState() => _DocumentReviewViewState();
}

class _DocumentReviewViewState extends State<DocumentReviewView> {
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(DocumentReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _selectFromImage(String key) {
    widget.controller.select(key);
    final BuildContext? ctx = _tileKeys[key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 250), alignment: 0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExtractionResult result = widget.controller.result;
    final bool hasImage = widget.showImage && widget.image != null;

    final Widget list = ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        for (final ExtractedField f in result.fields.values)
          KeyedSubtree(
            key: _tileKeys.putIfAbsent(f.key, GlobalKey.new),
            child: widget.fieldBuilder?.call(context, f, widget.controller) ??
                _FieldTile(
                  key: ValueKey<String>('field-${f.key}'),
                  field: f,
                  selected: widget.controller.selectedKey == f.key,
                  strings: widget.strings,
                  thresholds: widget.thresholds,
                  colors: widget.colors,
                  controller: widget.controller,
                ),
          ),
        if (widget.onSubmit != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                widget.onSubmit!(widget.controller.result);
              },
              child: Text(widget.strings.submit),
            ),
          ),
      ],
    );

    if (!hasImage) return list;

    final Widget image = _ImageWithBoxes(
      image: widget.image!,
      result: result,
      selectedKey: widget.controller.selectedKey,
      thresholds: widget.thresholds,
      colors: widget.colors,
      onTap: _selectFromImage,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  child:
                      Padding(padding: const EdgeInsets.all(12), child: image)),
              Expanded(child: list),
            ],
          );
        }
        return Column(
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.imageMaxHeight),
              child: Padding(padding: const EdgeInsets.all(12), child: image),
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

class _ImageWithBoxes extends StatelessWidget {
  const _ImageWithBoxes({
    required this.image,
    required this.result,
    required this.selectedKey,
    required this.thresholds,
    required this.colors,
    required this.onTap,
  });

  final ImageProvider image;
  final ExtractionResult result;
  final String? selectedKey;
  final ConfidenceThresholds thresholds;
  final ConfidenceColors colors;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final double? w = result.ocr.imageWidth;
    final double? h = result.ocr.imageHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return Image(image: image, fit: BoxFit.contain);
    }
    return Center(
      child: AspectRatio(
        aspectRatio: w / h,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double sx = c.maxWidth / w;
            final double sy = c.maxHeight / h;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image(image: image, fit: BoxFit.fill),
                for (final ExtractedField f in result.fields.values)
                  if (f.box != null)
                    _box(f, f.box!.scale(sx, sy), f.key == selectedKey),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _box(ExtractedField f, BoundingBox b, bool selected) {
    final Color color = colors.of(f, thresholds);
    return Positioned(
      left: b.left - 2,
      top: b.top - 2,
      width: b.width + 4,
      height: b.height + 4,
      child: Semantics(
        button: true,
        label: f.label,
        child: GestureDetector(
          onTap: () => onTap(f.key),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.25 : 0.1),
              border: Border.all(color: color, width: selected ? 3 : 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldTile extends StatefulWidget {
  const _FieldTile({
    super.key,
    required this.field,
    required this.selected,
    required this.strings,
    required this.thresholds,
    required this.colors,
    required this.controller,
  });

  final ExtractedField field;
  final bool selected;
  final ReviewStrings strings;
  final ConfidenceThresholds thresholds;
  final ConfidenceColors colors;
  final DocumentReviewController controller;

  @override
  State<_FieldTile> createState() => _FieldTileState();
}

class _FieldTileState extends State<_FieldTile> {
  late final TextEditingController _text =
      TextEditingController(text: widget.field.rawText ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        widget.controller.select(widget.field.key);
      } else {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(_FieldTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String text = widget.field.rawText ?? '';
    if (!_focus.hasFocus && text != _text.text) _text.text = text;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() => widget.controller.correct(widget.field.key, _text.text);

  TextInputType get _keyboard => switch (widget.field.definition.type) {
        FieldType.number ||
        FieldType.amount ||
        FieldType.nationalCode ||
        FieldType.cardNumber =>
          TextInputType.number,
        FieldType.phone => TextInputType.phone,
        FieldType.date || FieldType.time => TextInputType.datetime,
        _ => TextInputType.text,
      };

  /// Numbers, codes and dates read left to right even in Persian layouts.
  bool get _ltr => switch (widget.field.definition.type) {
        FieldType.text => false,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final ExtractedField f = widget.field;
    final ThemeData theme = Theme.of(context);
    final Color color = widget.colors.of(f, widget.thresholds);
    final ReviewStrings s = widget.strings;

    final String badge = f.source == FieldSource.user
        ? s.corrected
        : f.isMissing
            ? s.missing
            : '${s.confidence} ${(f.confidence * 100).round()}٪';

    String? error;
    if (!f.isValid && !(f.isMissing && !f.definition.required)) {
      error =
          f.isMissing || (f.rawText?.isEmpty ?? true) ? s.required : s.invalid;
    }

    return Card(
      elevation: widget.selected ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: widget.selected ? color : theme.dividerColor,
            width: widget.selected ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    f.definition.required ? '${f.label} *' : f.label,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    child: Text(badge,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: color, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              focusNode: _focus,
              keyboardType: _keyboard,
              textDirection: _ltr ? TextDirection.ltr : null,
              textAlign: _ltr && Directionality.of(context) == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.start,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: error,
              ),
            ),
            if (f.alternatives.isNotEmpty &&
                f.source != FieldSource.user) ...<Widget>[
              const SizedBox(height: 8),
              Text(s.alternatives, style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final FieldAlternative a in f.alternatives)
                    ActionChip(
                      label: Text(a.rawText),
                      onPressed: () {
                        _text.text = a.rawText;
                        _commit();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
