import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/money.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const provider = Provider(
    id: 'p1',
    kind: ProviderKind.clinician,
    displayName: 'Dr. Kojo Boateng',
    specialty: 'Cardiologist',
    rating: 4.8,
  );

  group('Money', () {
    test('formats whole cedis without decimals', () {
      expect(const Money(18000).formatted, 'GHS 180');
      expect(const Money(9000).formatted, 'GHS 90');
    });

    test('keeps pesewas when they are non-zero', () {
      expect(const Money(8950).formatted, 'GHS 89.50');
      expect(const Money(8905).formatted, 'GHS 89.05');
    });
  });

  group('Provider.distanceLabel', () {
    test('switches from metres to kilometres at 1 km', () {
      expect(provider.copyDistance(850).distanceLabel, '850 m');
      expect(provider.copyDistance(2100).distanceLabel, '2.1 km');
    });

    test('is null when location was declined, so callers can omit it', () {
      expect(provider.distanceLabel, isNull);
    });
  });

  group('Appointment.relativeLabel', () {
    final now = DateTime(2026, 9, 1, 9);

    Appointment at(DateTime when) => Appointment(
          id: 'a1',
          provider: provider,
          scheduledFor: when,
          status: AppointmentStatus.confirmed,
        );

    test('computes the weekday rather than trusting a hardcoded string', () {
      // 4 Sep 2026 is a Friday. Several Figma frames print a weekday that
      // does not match the date beside it; this is formatted from the value.
      expect(at(DateTime(2026, 9, 4, 14, 30)).relativeLabel(now: now),
          'Fri, 4 Sep · 2:30 PM');
    });

    test('uses relative wording for today and tomorrow', () {
      expect(at(DateTime(2026, 9, 1, 14, 30)).relativeLabel(now: now),
          'Today · 2:30 PM');
      expect(at(DateTime(2026, 9, 2, 9)).relativeLabel(now: now),
          'Tomorrow · 9:00 AM');
      expect(at(DateTime(2026, 8, 31, 16)).relativeLabel(now: now),
          'Yesterday · 4:00 PM');
    });
  });
}

extension on Provider {
  Provider copyDistance(double metres) => Provider(
        id: id,
        kind: kind,
        displayName: displayName,
        specialty: specialty,
        rating: rating,
        distanceMetres: metres,
      );
}
