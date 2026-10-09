import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../../home/domain/appointment.dart';
import 'appointments_event.dart';

enum AppointmentsStatus { loading, ready }

class AppointmentsState extends Equatable {
  const AppointmentsState({
    this.status = AppointmentsStatus.loading,
    this.appointments = const [],
    this.filter = AppointmentsFilter.upcoming,
    this.cancellingId,
    this.failure,
  });

  final AppointmentsStatus status;
  final List<Appointment> appointments;
  final AppointmentsFilter filter;

  /// The appointment whose cancel request is in flight, so only that row
  /// shows a spinner instead of the whole list.
  final String? cancellingId;

  final Failure? failure;

  List<Appointment> get visible => appointments
      .where((a) => filter == AppointmentsFilter.upcoming ? a.isActive : !a.isActive)
      .toList(growable: false);

  int get upcomingCount => appointments.where((a) => a.isActive).length;

  AppointmentsState copyWith({
    AppointmentsStatus? status,
    List<Appointment>? appointments,
    AppointmentsFilter? filter,
    String? cancellingId,
    bool clearCancelling = false,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AppointmentsState(
      status: status ?? this.status,
      appointments: appointments ?? this.appointments,
      filter: filter ?? this.filter,
      cancellingId: clearCancelling ? null : (cancellingId ?? this.cancellingId),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, appointments, filter, cancellingId, failure];
}
