import 'package:flutter_test/flutter_test.dart';
import 'package:polyfind/core/utils/validators.dart';

void main() {
  group('login identifier', () {
    test('accepts school emails at the institution domain', () {
      expect(
        Validators.validateSchoolEmail('student@thenyeripoly.ac.ke'),
        isNull,
      );
      expect(
        Validators.validateSchoolEmail('invalid@other-domain.test'),
        isNotNull,
      );
    });

    test('validates numeric admission numbers', () {
      expect(Validators.validateAdmissionNumber('48461'), isNull);
      expect(Validators.validateAdmissionNumber('not-a-number'), isNotNull);
      expect(Validators.validateAdmissionNumber(''), isNotNull);
    });

    test('requires a supported password length', () {
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
    });
  });
}
