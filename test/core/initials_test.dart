import 'package:carelite_app/core/utils/initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initialsOf', () {
    test('drops honorifics so a doctor reads by their name', () {
      // The Figma Notifications frame pairs "Dr. Ama Owusu" with a monogram
      // typed into a separate layer, and they disagree. Deriving avoids it.
      expect(initialsOf('Dr. Ama Owusu'), 'AO');
      expect(initialsOf('Dr Kojo Boateng'), 'KB');
      expect(initialsOf('Prof. Efua Mensah'), 'EM');
    });

    test('uses first and last name for longer names', () {
      expect(initialsOf('Esi Akosua Owusu'), 'EO');
    });

    test('handles a single name and messy whitespace', () {
      expect(initialsOf('Esi'), 'ES');
      expect(initialsOf('  Esi   Owusu  '), 'EO');
      expect(initialsOf('E'), 'E');
    });

    test('never throws on empty or honorific-only input', () {
      expect(initialsOf(''), '?');
      expect(initialsOf('Dr.'), '?');
    });
  });
}
