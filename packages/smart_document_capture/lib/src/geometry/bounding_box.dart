/// An axis aligned rectangle in image pixel coordinates.
///
/// The origin is the top-left corner of the image. This class is used instead
/// of `dart:ui`'s `Rect` so the extraction core stays pure Dart.
class BoundingBox {
  /// Creates a box from its edges.
  const BoundingBox.fromLTRB(this.left, this.top, this.right, this.bottom);

  /// Creates a box from its top-left corner and size.
  const BoundingBox.fromLTWH(double left, double top, double width,
      double height)
      : this.fromLTRB(left, top, left + width, top + height);

  /// Creates a box from JSON produced by [toJson].
  factory BoundingBox.fromJson(Map<String, dynamic> json) =>
      BoundingBox.fromLTRB(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['right'] as num).toDouble(),
        (json['bottom'] as num).toDouble(),
      );

  /// Smallest box containing every box of [boxes], or `null` when empty.
  static BoundingBox? unionAll(Iterable<BoundingBox?> boxes) {
    BoundingBox? result;
    for (final BoundingBox? box in boxes) {
      if (box == null) continue;
      result = result == null ? box : result.union(box);
    }
    return result;
  }

  /// Left edge.
  final double left;

  /// Top edge.
  final double top;

  /// Right edge.
  final double right;

  /// Bottom edge.
  final double bottom;

  /// Width of the box.
  double get width => right - left;

  /// Height of the box.
  double get height => bottom - top;

  /// Horizontal center.
  double get centerX => (left + right) / 2;

  /// Vertical center.
  double get centerY => (top + bottom) / 2;

  /// Smallest box containing this box and [other].
  BoundingBox union(BoundingBox other) => BoundingBox.fromLTRB(
        left < other.left ? left : other.left,
        top < other.top ? top : other.top,
        right > other.right ? right : other.right,
        bottom > other.bottom ? bottom : other.bottom,
      );

  /// Whether the center of [other] lies inside this box.
  bool containsCenterOf(BoundingBox other) =>
      other.centerX >= left &&
      other.centerX <= right &&
      other.centerY >= top &&
      other.centerY <= bottom;

  /// Returns this box with every coordinate multiplied by the factors.
  BoundingBox scale(double sx, double sy) =>
      BoundingBox.fromLTRB(left * sx, top * sy, right * sx, bottom * sy);

  /// Serializes the box.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };

  @override
  bool operator ==(Object other) =>
      other is BoundingBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'BoundingBox($left, $top, $right, $bottom)';
}
