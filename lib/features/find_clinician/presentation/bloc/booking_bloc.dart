import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../../home/domain/provider.dart';
import '../../data/clinician_repository.dart';
import '../../domain/booking_request.dart';
import 'booking_event.dart';
import 'booking_state.dart';

/// Drives both booking paths: a named clinician (the profile screen) and
/// "any available" (the match action on Find a Clinician). They differ only
/// in whether [BookingState.clinician] is set, so one Bloc serves both
/// rather than duplicating the submit/error handling twice.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc({
    required ClinicianRepository clinicianRepository,
    Provider? clinician,
    BookingMode mode = BookingMode.scheduled,
    this.replacesAppointmentId,
  })  : _clinicianRepository = clinicianRepository,
        super(BookingState(clinician: clinician, mode: mode)) {
    on<BookingStarted>(_onStarted);
    on<BookingModeChanged>(_onModeChanged);
    on<BookingSlotSelected>(_onSlotSelected);
    on<BookingReasonChanged>(_onReasonChanged);
    on<BookingSubmitted>(_onSubmitted);
  }

  final ClinicianRepository _clinicianRepository;

  /// Set when this booking replaces an appointment that fell through.
  final int? replacesAppointmentId;

  Future<void> _onStarted(
    BookingStarted event,
    Emitter<BookingState> emit,
  ) async {
    final clinician = state.clinician;
    // An "any available" booking has no clinician yet, so there are no slots
    // to fetch. It is on-demand by nature: the server matches whoever is
    // online now.
    if (clinician == null) return;

    final clinicianId = int.tryParse(clinician.id);
    if (clinicianId == null) {
      emit(state.copyWith(
        status: BookingStatus.ready,
        failure: const UnexpectedFailure(
          'That clinician could not be opened. Please pick another.',
        ),
      ));
      return;
    }

    emit(state.copyWith(status: BookingStatus.loadingSlots, clearFailure: true));

    try {
      final result = await _clinicianRepository.fetchSlots(clinicianId);
      result.when(
        ok: (slots) => emit(state.copyWith(
          status: BookingStatus.ready,
          slots: slots,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: BookingStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: BookingStatus.ready,
        failure: UnexpectedFailure(
          'Could not load available times (${e.runtimeType}).',
        ),
      ));
    }
  }

  void _onModeChanged(BookingModeChanged event, Emitter<BookingState> emit) {
    // Switching to on-demand drops any chosen slot: keeping it would leave a
    // time highlighted that the request no longer sends, and the server
    // clears `scheduled_at` for ON_DEMAND anyway.
    emit(state.copyWith(
      mode: event.mode,
      clearSelectedSlot: event.mode == BookingMode.onDemand,
      clearFailure: true,
    ));
  }

  void _onSlotSelected(BookingSlotSelected event, Emitter<BookingState> emit) {
    emit(state.copyWith(
      selectedSlot: event.slot,
      mode: BookingMode.scheduled,
      clearFailure: true,
    ));
  }

  void _onReasonChanged(BookingReasonChanged event, Emitter<BookingState> emit) {
    emit(state.copyWith(reason: event.reason));
  }

  Future<void> _onSubmitted(
    BookingSubmitted event,
    Emitter<BookingState> emit,
  ) async {
    if (state.isSubmitting) return;

    final request = state.request;
    if (!request.isValid) {
      // Should be unreachable — the button is disabled — but a 400 must
      // never be how the patient discovers they forgot to pick a time.
      emit(state.copyWith(
        failure: const ValidationFailure('Choose a time to continue.'),
      ));
      return;
    }

    emit(state.copyWith(status: BookingStatus.submitting, clearFailure: true));

    try {
      final result = await _clinicianRepository
          .book(request.replacing(replacesAppointmentId));
      result.when(
        ok: (appointment) => emit(state.copyWith(
          status: BookingStatus.booked,
          booked: appointment,
          clearFailure: true,
        )),
        // Back to ready, not booked: the patient must be able to change the
        // time and try again. `booked` is never set on this path, so no
        // caller can mistake a rejection for a confirmed appointment.
        err: (failure) => emit(state.copyWith(
          status: BookingStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: BookingStatus.ready,
        failure: UnexpectedFailure(
          'Could not complete the booking (${e.runtimeType}).',
        ),
      ));
    }
  }
}
