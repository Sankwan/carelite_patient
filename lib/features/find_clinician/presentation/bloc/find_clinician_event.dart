import 'package:equatable/equatable.dart';

sealed class FindClinicianEvent extends Equatable {
  const FindClinicianEvent();

  @override
  List<Object?> get props => [];
}

final class FindClinicianStarted extends FindClinicianEvent {
  const FindClinicianStarted();
}

/// The search field, already debounced by the caller.
final class FindClinicianSpecialtyChanged extends FindClinicianEvent {
  const FindClinicianSpecialtyChanged(this.specialty);

  final String specialty;

  @override
  List<Object?> get props => [specialty];
}

final class FindClinicianAvailabilityToggled extends FindClinicianEvent {
  const FindClinicianAvailabilityToggled();
}

final class FindClinicianFiltersCleared extends FindClinicianEvent {
  const FindClinicianFiltersCleared();
}

final class FindClinicianRetried extends FindClinicianEvent {
  const FindClinicianRetried();
}
