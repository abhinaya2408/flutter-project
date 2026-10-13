import 'package:college_bakery_flutter/utils/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumber.toE164', () {
    test('accepts an already international number', () {
      expect(PhoneNumber.toE164('+919876543210'), '+919876543210');
    });

    test('strips spaces, dashes, dots and brackets', () {
      expect(PhoneNumber.toE164('+91 98765-43210'), '+919876543210');
      expect(PhoneNumber.toE164('(987) 654.3210'), '+919876543210');
    });

    test('prepends the selected dial code to a national number', () {
      expect(PhoneNumber.toE164('9876543210'), '+919876543210');
      expect(
        PhoneNumber.toE164('7911123456', dialCode: '+44'),
        '+447911123456',
      );
    });

    test('handles a leading trunk zero', () {
      expect(PhoneNumber.toE164('09876543210'), '+919876543210');
    });

    test('handles a 00 international prefix', () {
      expect(PhoneNumber.toE164('00919876543210'), '+919876543210');
    });

    test('treats a long digit-only value as international', () {
      expect(PhoneNumber.toE164('919876543210'), '+919876543210');
    });

    test('rejects input that cannot be a phone number', () {
      expect(PhoneNumber.toE164(''), isNull);
      expect(PhoneNumber.toE164('   '), isNull);
      expect(PhoneNumber.toE164('abcdefghij'), isNull);
      expect(PhoneNumber.toE164('123'), isNull);
      expect(PhoneNumber.toE164('+0123456789'), isNull);
      expect(PhoneNumber.toE164('+1234567890123456'), isNull);
      expect(PhoneNumber.toE164('0009876543210'), isNull);
    });
  });

  group('PhoneNumber.mask', () {
    test('keeps the country code and the last four digits', () {
      expect(PhoneNumber.mask('+919876543210'), '+91 ••••••3210');
    });

    test('handles a single-digit country code', () {
      expect(PhoneNumber.mask('+14155552671'), '+1 ••••••2671');
    });

    test('never reveals more digits than it was given', () {
      expect(PhoneNumber.mask('+919876543210').replaceAll(RegExp(r'\D'), '').length, 6);
    });

    test('degrades safely for very short values', () {
      expect(PhoneNumber.mask('+12'), '••');
      expect(PhoneNumber.mask(''), '');
    });
  });
}
