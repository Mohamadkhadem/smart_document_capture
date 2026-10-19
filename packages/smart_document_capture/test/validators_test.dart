import 'package:flutter_test/flutter_test.dart';
import 'package:persian_calendar_kit/persian_calendar_kit.dart';
import 'package:smart_document_capture/smart_document_capture.dart';

void main() {
  test('text normalizer', () {
    expect(TextNormalizer.normalize('۱۲۳٬۴۵۶ ريال'), '123,456 ریال');
    expect(TextNormalizer.digitsOnly('۰۹۱۲-۱۲۳ ۴۵۶۷'), '09121234567');
    expect(TextNormalizer.forMatching('جمع  کل:'), 'جمع کل');
  });

  test('national code', () {
    const NationalCodeValidator v = NationalCodeValidator();
    expect(v.validate('۰۴۹۹۳۷۰۸۹۹').value, '0499370899');
    expect(v.validate('049-937089-9').isValid, isTrue);
    expect(v.validate('84575948').value, '0084575948'); // padded
    expect(v.validate('0499370898').isValid, isFalse); // checksum
    expect(v.validate('1111111111').isValid, isFalse); // repeated digit
    expect(v.validate('12345').isValid, isFalse);
  });

  test('bank card', () {
    expect(const BankCardValidator().validate('6037-9912-3456-7893').value,
        '6037991234567893');
    expect(const BankCardValidator().validate('6037991234567890').isValid,
        isFalse);
    expect(const BankCardValidator().validate('6037-99**-****-7893').isValid,
        isFalse);
    expect(
        const BankCardValidator(allowMasked: true)
            .validate('۶۰۳۷-۹۹xx-xxxx-۷۸۹۳')
            .value,
        '603799******7893');
  });

  test('sheba', () {
    const ShebaValidator v = ShebaValidator();
    expect(v.validate('IR06 2960 0000 0010 0324 2000 01').value,
        'IR062960000000100324200001');
    expect(v.validate('820540102680020817909002').value,
        'IR820540102680020817909002');
    expect(v.validate('IR062960000000100324200002').isValid, isFalse);
  });

  test('mobile number', () {
    const MobileNumberValidator v = MobileNumberValidator();
    expect(v.validate('+98 912 123 4567').value, '09121234567');
    expect(v.validate('۹۱۲۱۲۳۴۵۶۷').value, '09121234567');
    expect(v.validate('02112345678').isValid, isFalse);
  });

  test('jalali date', () {
    const JalaliDateValidator v = JalaliDateValidator();
    expect(v.validate('۱۴۰۴/۰۷/۲۷').value, JalaliDate(1404, 7, 27));
    expect(v.validate('04-7-27').value, JalaliDate(1404, 7, 27));
    expect(v.validate('27.07.1404').value, JalaliDate(1404, 7, 27));
    expect(v.validate('99/12/30').value, JalaliDate(1399, 12, 30));
    expect(v.validate('1404/12/30').isValid, isFalse); // 1404 is not leap
    expect(v.validate('1404/13/01').isValid, isFalse);
    expect(v.validate('2025/03/21').isValid, isFalse);
    expect(const JalaliDateValidator(acceptGregorian: true)
            .validate('2025/03/21')
            .value,
        JalaliDate(1404, 1, 1));
  });

  test('amount, number and time', () {
    expect(const AmountValidator().validate('۱٬۲۵۰٬۰۰۰ ریال').value, 1250000);
    expect(const AmountValidator().validate('850000 تومان').value, 850000);
    expect(const AmountValidator().validate('0').isValid, isFalse);
    expect(const AmountValidator().validate('12,34').isValid, isFalse);
    expect(const NumberValidator(max: 10).validate('12').isValid, isFalse);
    expect(const NumberValidator().validate('12.5').value, 12.5);
    expect(const TimeValidator().validate('۸:۰۵').value, '08:05');
    expect(const TimeValidator().validate('24:00').isValid, isFalse);
  });

  test('regex and text validators', () {
    expect(RegexValidator(RegExp(r'\d{4}')).validate('۱۲۳۴').isValid, isTrue);
    expect(RegexValidator(RegExp(r'\d{4}')).validate('12345').isValid, isFalse);
    expect(const TextValidator(minLength: 3).validate(' ab ').isValid, isFalse);
  });
}
