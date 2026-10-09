import '../../../core/utils/result.dart';
import '../../home/domain/appointment.dart';
import '../../home/domain/provider.dart';
import '../domain/booking_request.dart';
import '../domain/search_filter.dart';

abstract class ClinicianRepository {
  /// Verified clinicians matching [filter], highest-rated first.
  Future<Result<List<Provider>>> search(ClinicianFilter filter);

  /// The clinician's bookable times, already in local time and sorted.
  ///
  /// An empty list is a real answer (the clinician has no availability
  /// windows set), not an error — the caller must render it as such rather
  /// than as a failure.
  Future<Result<List<DateTime>>> fetchSlots(int clinicianId, {int days});

  /// Creates the appointment. Returns the created [Appointment] so the
  /// caller can confirm what was actually booked — for an `ANY` request that
  /// is the only way to learn which clinician the server matched.
  Future<Result<Appointment>> book(BookingRequest request);
}
