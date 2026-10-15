import 'package:carelite_app/features/find_clinician/domain/booking_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a replacement booking names the appointment it replaces', () {
    final json = BookingRequest.specific(
      clinicianId: 3,
      mode: BookingMode.onDemand,
    ).replacing(32).toJson();

    expect(json['replaces'], 32);
    expect(json['clinician'], 3);
  });

  test('an ordinary booking sends no replaces field', () {
    final json =
        BookingRequest.specific(clinicianId: 3, mode: BookingMode.onDemand)
            .toJson();

    expect(json.containsKey('replaces'), isFalse);
  });
}
