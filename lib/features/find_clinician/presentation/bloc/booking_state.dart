import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../../home/domain/appointment.dart';
import '../../../home/domain/provider.dart';
import '../../domain/booking_request.dart';

enum BookingStatus { loadingSlots, ready, submitting, booked }

class BookingState extends Equatable {
  const BookingState({
    this.status = BookingStatus.ready,
    this.clinician,
    this.slots = const [],
    this.selectedSlot,
    this.mode = BookingMode.scheduled,
    this.reason = '',
    this.booked,
    this.failure,
  });

  /// Null for an "any available" booking — the server picks the clinician,
  /// so there is nobody to show until the appointment comes back.
  final Provider? clinician;

  final BookingStatus status;
  final List<DateTime> slots;
  final DateTime? selectedSlot;
  final BookingMode mode;
  final String reason;

  /// Set once the server has confirmed. For an `ANY` booking this is the
  /// only place the matched clinician's name appears.
  final Appointment? booked;

  final Failure? failure;

  bool get isSubmitting => status == BookingStatus.submitting;

  /// The clinician has no availability windows configured. Distinct from
  /// "still loading" and from "failed" — it needs its own copy, offering an
  /// on-demand request instead of a dead end.
  bool get hasNoSlots =>
      status != BookingStatus.loadingSlots && slots.isEmpty && clinician != null;

  /// Slots grouped by calendar day, in order — what the day/time picker
  /// renders. Computed rather than stored so it can never disagree with
  /// [slots].
  Map<DateTime, List<DateTime>> get slotsByDay {
    final grouped = <DateTime, List<DateTime>>{};
    for (final slot in slots) {
      final day = DateTime(slot.year, slot.month, slot.day);
      grouped.putIfAbsent(day, () => []).add(slot);
    }
    return grouped;
  }

  /// The request this state would submit — the single source of truth for
  /// both the button's enabled state and what actually gets sent, so they
  /// can never disagree.
  BookingRequest get request {
    final clinicianId = clinician == null ? null : int.tryParse(clinician!.id);
    if (clinicianId == null) {
      return BookingRequest.any(
        mode: mode,
        scheduledFor: selectedSlot,
        reason: reason,
      );
    }
    return BookingRequest.specific(
      clinicianId: clinicianId,
      mode: mode,
      scheduledFor: selectedSlot,
      reason: reason,
    );
  }

  bool get canSubmit => request.isValid && !isSubmitting;

  BookingState copyWith({
    BookingStatus? status,
    Provider? clinician,
    List<DateTime>? slots,
    DateTime? selectedSlot,
    bool clearSelectedSlot = false,
    BookingMode? mode,
    String? reason,
    Appointment? booked,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return BookingState(
      status: status ?? this.status,
      clinician: clinician ?? this.clinician,
      slots: slots ?? this.slots,
      selectedSlot:
          clearSelectedSlot ? null : (selectedSlot ?? this.selectedSlot),
      mode: mode ?? this.mode,
      reason: reason ?? this.reason,
      booked: booked ?? this.booked,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        status, clinician, slots, selectedSlot, mode, reason, booked, failure,
      ];
}
