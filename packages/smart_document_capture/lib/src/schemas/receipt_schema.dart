import '../extraction/document_schema.dart';
import '../extraction/field_definition.dart';
import '../extraction/field_locator.dart';
import '../validation/field_validator.dart';
import '../validation/iranian_validators.dart';
import 'patterns.dart';

/// Ready-made schemas for purchase receipts.
abstract final class ReceiptSchema {
  /// Store receipts and card-reader (POS) slips in Persian, with English
  /// labels as a fallback.
  ///
  /// | key | type | value |
  /// |---|---|---|
  /// | `storeName` | text | `String` |
  /// | `date` | date | `JalaliDate` (required) |
  /// | `time` | time | `String` |
  /// | `total` | amount | `num` (required) |
  /// | `invoiceNumber` | identifier | `String` |
  /// | `trackingNumber` | identifier | `String` |
  /// | `cardNumber` | cardNumber | `String`, possibly masked |
  static final DocumentSchema persian = DocumentSchema(
    id: 'receipt',
    name: 'رسید خرید',
    fields: <FieldDefinition>[
      const FieldDefinition(
        key: 'storeName',
        label: 'نام فروشگاه',
        locators: <FieldLocator>[
          KeywordLocator(
              <String>['نام فروشگاه', 'فروشگاه:', 'نام پذیرنده', 'پذیرنده:'],
              searchNextLine: false),
          HeaderLocator(),
        ],
        validator: TextValidator(minLength: 2),
      ),
      FieldDefinition(
        key: 'date',
        label: 'تاریخ',
        type: FieldType.date,
        required: true,
        locators: <FieldLocator>[
          KeywordLocator(<String>['تاریخ', 'date'], value: ValuePatterns.date),
          PatternLocator(ValuePatterns.date, score: 0.7),
        ],
        validator: const JalaliDateValidator(acceptGregorian: true),
      ),
      FieldDefinition(
        key: 'time',
        label: 'ساعت',
        type: FieldType.time,
        locators: <FieldLocator>[
          KeywordLocator(<String>['ساعت', 'زمان', 'time'],
              value: ValuePatterns.time),
          PatternLocator(ValuePatterns.time, score: 0.7),
        ],
        validator: const TimeValidator(),
      ),
      FieldDefinition(
        key: 'total',
        label: 'مبلغ کل',
        type: FieldType.amount,
        required: true,
        pickLast: true,
        locators: <FieldLocator>[
          KeywordLocator(<String>[
            'مبلغ قابل پرداخت',
            'قابل پرداخت',
            'جمع کل',
            'مبلغ کل',
            'مبلغ تراکنش',
            'grand total',
            'total',
          ], value: ValuePatterns.amount),
          KeywordLocator(<String>['مبلغ', 'جمع', 'amount', 'sum'],
              value: ValuePatterns.amount,
              sameLineScore: 0.8,
              nextLineScore: 0.65),
        ],
        validator: const AmountValidator(),
      ),
      FieldDefinition(
        key: 'invoiceNumber',
        label: 'شماره فاکتور',
        type: FieldType.identifier,
        locators: <FieldLocator>[
          KeywordLocator(<String>[
            'شماره فاکتور',
            'شماره فیش',
            'شماره رسید',
            'شماره سند',
            'invoice no',
            'receipt no',
          ], value: RegExp(r'\d[\d\-/]*')),
        ],
        validator: RegexValidator(RegExp(r'\d[\d\-/]*')),
      ),
      FieldDefinition(
        key: 'trackingNumber',
        label: 'شماره پیگیری',
        type: FieldType.identifier,
        locators: <FieldLocator>[
          KeywordLocator(<String>[
            'شماره پیگیری',
            'کد پیگیری',
            'پیگیری',
            'شماره مرجع',
            'مرجع',
            'rrn',
            'trace',
          ], value: ValuePatterns.reference),
        ],
        validator: RegexValidator(RegExp(r'\d{4,}')),
      ),
      FieldDefinition(
        key: 'cardNumber',
        label: 'شماره کارت',
        type: FieldType.cardNumber,
        locators: <FieldLocator>[
          KeywordLocator(<String>['شماره کارت', 'کارت', 'card no', 'card'],
              value: ValuePatterns.cardNumber),
          PatternLocator(ValuePatterns.cardNumber, score: 0.6),
        ],
        validator: const BankCardValidator(allowMasked: true),
      ),
    ],
  );
}
