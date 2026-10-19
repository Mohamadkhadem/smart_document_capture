import '../validation/field_validator.dart';
import 'field_locator.dart';

/// Coarse buckets of a confidence score, for UI and routing decisions.
enum ConfidenceLevel {
  /// Below [ConfidenceThresholds.medium]: should be reviewed by a person.
  low,

  /// Between the thresholds: worth a glance.
  medium,

  /// At or above [ConfidenceThresholds.high]: safe to accept.
  high;

  /// Bucket of [score] using [thresholds].
  static ConfidenceLevel of(double score,
      [ConfidenceThresholds thresholds = const ConfidenceThresholds()]) {
    if (score >= thresholds.high) return ConfidenceLevel.high;
    if (score >= thresholds.medium) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

/// Limits between [ConfidenceLevel]s.
class ConfidenceThresholds {
  /// Creates thresholds.
  const ConfidenceThresholds({this.medium = 0.6, this.high = 0.85});

  /// Lowest score that counts as [ConfidenceLevel.medium].
  final double medium;

  /// Lowest score that counts as [ConfidenceLevel.high].
  final double high;
}

/// Turns a candidate and its validation into a confidence score.
abstract interface class ConfidenceModel {
  /// Score between 0 and 1 for [candidate].
  ///
  /// [validation] is `null` when the field has no validator. [agreeing] is
  /// the number of other candidates that produced the same value.
  double score(FieldCandidate candidate, ValidationResult? validation,
      {int agreeing = 0});
}

/// The default [ConfidenceModel]:
///
/// `ocrConfidence × matchScore × validationFactor + agreementBonus`
///
/// * `validationFactor` is 1 for valid text, [unvalidatedFactor] when the
///   field has no validator and [invalidFactor] for invalid text.
/// * `agreementBonus` is [agreementBonus] for each other candidate with the
///   same value, up to [maxAgreementBonus].
///
/// The result is clamped to 0…1.
class DefaultConfidenceModel implements ConfidenceModel {
  /// Creates the model.
  const DefaultConfidenceModel({
    this.unvalidatedFactor = 0.9,
    this.invalidFactor = 0.35,
    this.agreementBonus = 0.05,
    this.maxAgreementBonus = 0.1,
  });

  /// Factor for fields without a validator.
  final double unvalidatedFactor;

  /// Factor for text that failed validation.
  final double invalidFactor;

  /// Bonus for each agreeing candidate.
  final double agreementBonus;

  /// Upper limit of the total agreement bonus.
  final double maxAgreementBonus;

  @override
  double score(FieldCandidate candidate, ValidationResult? validation,
      {int agreeing = 0}) {
    final double factor = validation == null
        ? unvalidatedFactor
        : validation.isValid
            ? 1
            : invalidFactor;
    double bonus = agreeing * agreementBonus;
    if (bonus > maxAgreementBonus) bonus = maxAgreementBonus;
    final double s =
        candidate.ocrConfidence * candidate.matchScore * factor + bonus;
    return s.clamp(0.0, 1.0).toDouble();
  }
}
