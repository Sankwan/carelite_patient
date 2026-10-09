
import '../../../core/utils/result.dart';
import '../domain/appointment.dart';

abstract class AppointmentRepository {
  /// The next appointment the patient can still attend, or null — which is
  /// what puts Home into its new-user state.
  Future<Result<Appointment?>> fetchUpcoming(String patientId);

  /// Most recently completed appointments, newest first — the source of the
  /// Recent Activity section.
  Future<Result<List<Appointment>>> fetchRecent(String patientId, {int limit});

  /// Every appointment the server returns for this patient, newest first.
  ///
  /// Unfiltered on purpose: the Appointments screen splits them into its own
  /// tabs, and the endpoint is already scoped to "mine" server-side.
  Future<Result<List<Appointment>>> fetchAll();

  /// Cancels an appointment, returning it in its new state.
  ///
  /// The server is the authority on whether a cancel is allowed (a COMPLETED
  /// or CANCELLED one is refused), so this never assumes success.
  Future<Result<Appointment>> cancel(String appointmentId);
}
