import 'package:carelite_app/core/utils/appointments_changed.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_bloc.dart';
import 'package:carelite_app/features/home/data/appointment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppointmentRepository extends Mock implements AppointmentRepository {}

void main() {
  test('the appointments list reloads when a booking is made elsewhere',
      () async {
    // The tab stays alive behind the call and booking screens, so without
    // this it would still show the appointment that was just replaced.
    final repository = _MockAppointmentRepository();
    when(repository.fetchAll).thenAnswer((_) async => const Result.ok([]));
    final signal = AppointmentsChanged();
    final bloc = AppointmentsBloc(
      appointmentRepository: repository,
      appointmentsChanged: signal.stream,
    );
    addTearDown(bloc.close);

    signal.notify();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(repository.fetchAll).called(1);
  });
}
