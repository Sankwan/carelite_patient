import 'package:equatable/equatable.dart';

import '../../domain/booking_request.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the clinician's bookable times. Skipped entirely for an "any
/// available" booking, which has no clinician to load slots for.
final class BookingStarted extends BookingEvent {
  const BookingStarted();
}

final class BookingModeChanged extends BookingEvent {
  const BookingModeChanged(this.mode);

  final BookingMode mode;

  @override
  List<Object?> get props => [mode];
}

final class BookingSlotSelected extends BookingEvent {
  const BookingSlotSelected(this.slot);

  final DateTime slot;

  @override
  List<Object?> get props => [slot];
}

final class BookingReasonChanged extends BookingEvent {
  const BookingReasonChanged(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

final class BookingSubmitted extends BookingEvent {
  const BookingSubmitted();
}
