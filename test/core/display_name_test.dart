import 'package:carelite_app/core/utils/display_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatUsername', () {
    test('turns a clinician username into "Dr. Surname"', () {
      expect(formatUsername('dr_adjei'), 'Dr. Adjei');
      expect(formatUsername('dr_owusu'), 'Dr. Owusu');
      expect(formatUsername('dr_van_der_berg'), 'Dr. Van Der Berg');
    });

    test('capitalizes a single-word username with no underscore', () {
      expect(formatUsername('kofi'), 'Kofi');
      expect(formatUsername('ama'), 'Ama');
    });

    test('title-cases a plain snake_case username with no dr_ prefix', () {
      expect(formatUsername('op_lab'), 'Op Lab');
    });

    test('a real name already shaped like a name passes through unchanged',
        () {
      // Presentation only: never invent or re-derive something the backend
      // already sent in a usable form.
      expect(formatUsername('Kwame Adjei'), 'Kwame Adjei');
    });

    test('never throws on empty or degenerate input', () {
      expect(formatUsername(''), '');
      expect(formatUsername('dr'), 'Dr');
      expect(formatUsername('dr_'), 'Dr');
      expect(formatUsername('_'), '');
    });

    test('is idempotent — formatting twice gives the same result', () {
      final once = formatUsername('dr_adjei');
      expect(formatUsername(once), once);
    });
  });
}
