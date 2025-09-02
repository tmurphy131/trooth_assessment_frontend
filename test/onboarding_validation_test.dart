import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/utils/onboarding_validation.dart';

void main() {
  group('Onboarding validation', () {
    test('detects missing fields', () {
      final r = validateOnboarding('', '', null);
      expect(r.firstNameError, isNotNull);
      expect(r.lastNameError, isNotNull);
      expect(r.roleError, isNotNull);
      expect(r.hasErrors, isTrue);
    });

    test('accepts valid input', () {
      final r = validateOnboarding('Alice', 'Smith', 'mentor');
      expect(r.firstNameError, isNull);
      expect(r.lastNameError, isNull);
      expect(r.roleError, isNull);
      expect(r.hasErrors, isFalse);
    });

    test('rejects invalid characters', () {
      final r = validateOnboarding('Al!ce', 'Sm!th', 'apprentice');
      expect(r.firstNameError, isNotNull);
      expect(r.lastNameError, isNotNull);
    });
  });
}
