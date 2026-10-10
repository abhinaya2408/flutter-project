import 'package:college_bakery_flutter/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('student login', () {
    test('email must be present and contain @', () {
      expect(Validators.loginEmail(''), Validators.emailRequired);
      expect(Validators.loginEmail('ananya'), Validators.emailRequired);
      expect(Validators.loginEmail('ananya@yourcollege.edu'), isNull);
    });

    test('password must be present', () {
      expect(Validators.loginPassword(''), Validators.passwordRequired);
      expect(Validators.loginPassword('x'), isNull);
    });
  });

  group('student registration', () {
    test('full name and student id are required', () {
      expect(Validators.fullName('   '), Validators.fullNameRequired);
      expect(Validators.studentId(''), Validators.studentIdRequired);
      expect(Validators.fullName('Ananya Sharma'), isNull);
      expect(Validators.studentId('STU2024001'), isNull);
    });

    test('phone must be exactly ten digits', () {
      expect(Validators.phone('98765'), Validators.phoneInvalid);
      expect(Validators.phone('98765432101'), Validators.phoneInvalid);
      expect(Validators.phone('98765abcde'), Validators.phoneInvalid);
      expect(Validators.phone('9876543210'), isNull);
    });

    test('email must end with the college domain', () {
      expect(
        Validators.collegeEmail('someone@gmail.com'),
        Validators.collegeEmailRequired,
      );
      expect(Validators.collegeEmail('ananya.sharma@yourcollege.edu'), isNull);
      expect(
        Validators.collegeEmail('ANANYA@YOURCOLLEGE.EDU'),
        isNull,
      );
    });

    test('password needs six characters', () {
      expect(Validators.password('12345'), Validators.passwordTooShort);
      expect(Validators.password('123456'), isNull);
    });

    test('confirm password must match', () {
      expect(
        Validators.confirmPassword('abc123', 'abc124'),
        Validators.passwordsDoNotMatch,
      );
      expect(
        Validators.confirmPassword('', 'abc123'),
        Validators.passwordsDoNotMatch,
      );
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
    });
  });

  group('place order', () {
    test('missing field message keeps the original wording', () {
      expect(
        Validators.missingFieldsMessage(<String>[
          'cake flavor',
          'cake type (Egg/Eggless)',
          'cake size',
          'cream',
          'required date',
        ]),
        'Please complete: cake flavor, cake type (Egg/Eggless), cake size, '
        'cream, required date.',
      );
    });

    test('date and time messages', () {
      expect(Validators.requiredDate(null), Validators.dateRequired);
      expect(Validators.requiredTime(''), Validators.timeRequired);
      expect(Validators.dateNotInPast('2026-10-01', today: '2026-10-05'),
          Validators.dateInPast);
      expect(Validators.dateNotInPast('2026-10-05', today: '2026-10-05'), isNull);
    });
  });

  group('reference image limits', () {
    test('accept list and size limit', () {
      expect(
        Validators.allowedImageMimeTypes,
        <String>['image/jpeg', 'image/jpg', 'image/png'],
      );
      expect(
        Validators.allowedImageExtensions,
        <String>['jpg', 'jpeg', 'png'],
      );
      expect(Validators.maxImageBytes, 2 * 1024 * 1024);
      expect(Validators.cakeMessageMaxLength, 50);
    });
  });
}
