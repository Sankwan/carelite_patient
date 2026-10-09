import 'package:equatable/equatable.dart';

sealed class AppointmentsEvent extends Equatable {
  const AppointmentsEvent();

  @override
  List<Object?> get props => [];
}

final class AppointmentsStarted extends AppointmentsEvent {
  const AppointmentsStarted();
}

final class AppointmentsRefreshed extends AppointmentsEvent {
  const AppointmentsRefreshed();
}

final class AppointmentsFilterChanged extends AppointmentsEvent {
  const AppointmentsFilterChanged(this.filter);

  final AppointmentsFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class AppointmentCancelled extends AppointmentsEvent {
  const AppointmentCancelled(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Upcoming = anything the patient can still act on; Past = finished or
/// cancelled. Together they cover every status, so no appointment can fall
/// between the tabs and become invisible.
enum AppointmentsFilter { upcoming, past }
