import 'package:equatable/equatable.dart';

/// Who the appointment is with.
///
/// `ANY` is this backend's entire "find me a doctor" feature: the server
/// picks the highest-rated verified clinician matching the request
/// (`appointments.matching.match_clinician`) and returns an appointment with
/// that clinician already attached — or a 400 saying nobody matched. It is
/// synchronous and single-shot, so there is no "searching…" state to render
/// and no candidate list to watch.
enum BookingType {
  specific('SPECIFIC'),
  any('ANY');

  const BookingType(this.wireValue);

  final String wireValue;
}

/// When the appointment happens.
enum BookingMode {
  /// Requires [BookingRequest.scheduledFor]; the server rejects it otherwise.
  scheduled('SCHEDULED'),

  /// The server clears `scheduled_at` for these, and — for an `ANY` booking —
  /// only matches a clinician who is currently online.
  onDemand('ON_DEMAND');

  const BookingMode(this.wireValue);

  final String wireValue;
}

/// The body of `POST /api/appointments/`, verified field-by-field against
/// `appointments.serializers.BookingSerializer` on a running instance.
class BookingRequest extends Equatable {
  const BookingRequest({
    required this.type,
    required this.mode,
    this.clinicianId,
    this.scheduledFor,
    this.reason = '',
    this.specialty,
  });

  /// Book a named clinician.
  factory BookingRequest.specific({
    required int clinicianId,
    required BookingMode mode,
    DateTime? scheduledFor,
    String reason = '',
  }) {
    return BookingRequest(
      type: BookingType.specific,
      mode: mode,
      clinicianId: clinicianId,
      scheduledFor: scheduledFor,
      reason: reason,
    );
  }

  /// Let the server match one.
  factory BookingRequest.any({
    required BookingMode mode,
    DateTime? scheduledFor,
    String reason = '',
    String? specialty,
  }) {
    return BookingRequest(
      type: BookingType.any,
      mode: mode,
      scheduledFor: scheduledFor,
      reason: reason,
      specialty: specialty,
    );
  }

  final BookingType type;
  final BookingMode mode;
  final int? clinicianId;
  final DateTime? scheduledFor;
  final String reason;

  /// Only meaningful for an `ANY` booking — the server ignores it otherwise.
  final String? specialty;

  /// True when this request is complete enough for the server to accept it.
  /// Checked before enabling the button so a predictable 400 is never the
  /// way the patient finds out.
  bool get isValid {
    if (mode == BookingMode.scheduled && scheduledFor == null) return false;
    if (type == BookingType.specific && clinicianId == null) return false;
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_type': type.wireValue,
      'mode': mode.wireValue,
      // The field is `clinician`, NOT `clinician_id` — the response nests a
      // full clinician object under this same key, which makes the wrong
      // guess the natural one. See ApiContract.bookingClinicianField.
      if (type == BookingType.specific && clinicianId != null)
        'clinician': clinicianId,
      // Sent as null for ON_DEMAND rather than omitted: the server clears it
      // either way, and being explicit keeps the payload readable in logs.
      //
      // Read null-safely even though [isValid] should have stopped an
      // incomplete SCHEDULED request from getting here. A `!` would turn a
      // caller's bug into a TypeError thrown out of the repository — which
      // catches DioException, not that — and the booking screen would hang
      // on its spinner instead of showing the 400 the server would have
      // sent back. Letting the server reject it is the honest failure.
      'scheduled_at': mode == BookingMode.scheduled
          ? scheduledFor?.toUtc().toIso8601String()
          : null,
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (type == BookingType.any &&
          (specialty?.trim().isNotEmpty ?? false))
        'specialty': specialty!.trim(),
    };
  }

  @override
  List<Object?> get props =>
      [type, mode, clinicianId, scheduledFor, reason, specialty];
}
