import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_bloc.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_event.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_state.dart';
import 'package:carelite_app/features/home/data/appointment_repository.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppointmentRepository extends Mock implements AppointmentRepository {}

void main() {
  late _MockAppointmentRepository repository;

  const clinician = Provider(
    id: '5',
    kind: ProviderKind.clinician,
    displayName: 'dr_adjei',
    specialty: 'Cardiology',
  );

  Appointment build(String id, AppointmentStatus status) => Appointment(
        id: id,
        provider: clinician,
        scheduledFor: DateTime.now().add(const Duration(days: 1)),
        status: status,
      );

  late Appointment requested;
  late Appointment confirmed;
  late Appointment completed;
  late Appointment cancelled;

  setUp(() {
    repository = _MockAppointmentRepository();
    requested = build('1', AppointmentStatus.requested);
    confirmed = build('2', AppointmentStatus.confirmed);
    completed = build('3', AppointmentStatus.completed);
    cancelled = build('4', AppointmentStatus.cancelled);

    when(() => repository.fetchAll()).thenAnswer(
      (_) async => Result.ok([requested, confirmed, completed, cancelled]),
    );
  });

  AppointmentsBloc buildBloc() =>
      AppointmentsBloc(appointmentRepository: repository);

  group('AppointmentsBloc', () {
    blocTest<AppointmentsBloc, AppointmentsState>(
      'the two tabs together account for every appointment',
      build: buildBloc,
      act: (bloc) => bloc.add(const AppointmentsStarted()),
      skip: 1,
      verify: (bloc) {
        // Nothing may fall between Upcoming and Past and become invisible.
        final upcoming = bloc.state.visible;
        final past = bloc.state
            .copyWith(filter: AppointmentsFilter.past)
            .visible;
        expect(upcoming.map((a) => a.id), ['1', '2']);
        expect(past.map((a) => a.id), ['3', '4']);
        expect(
          upcoming.length + past.length,
          bloc.state.appointments.length,
        );
      },
    );

    blocTest<AppointmentsBloc, AppointmentsState>(
      'filtering does not re-query — the endpoint has no ?status= filter',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AppointmentsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppointmentsFilterChanged(AppointmentsFilter.past));
      },
      verify: (bloc) {
        verify(() => repository.fetchAll()).called(1);
        expect(bloc.state.filter, AppointmentsFilter.past);
      },
    );

    blocTest<AppointmentsBloc, AppointmentsState>(
      'a cancel is not optimistic: the row only changes once the server '
      'confirms it',
      build: () {
        when(() => repository.cancel('2')).thenAnswer(
          (_) async => Result.ok(build('2', AppointmentStatus.cancelled)),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const AppointmentsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppointmentCancelled('2'));
      },
      verify: (bloc) {
        final updated =
            bloc.state.appointments.firstWhere((a) => a.id == '2');
        expect(updated.status, AppointmentStatus.cancelled);
        expect(bloc.state.cancellingId, isNull);
        // It has moved from Upcoming to Past.
        expect(bloc.state.visible.map((a) => a.id), ['1']);
      },
    );

    blocTest<AppointmentsBloc, AppointmentsState>(
      'a refused cancel leaves the appointment exactly as it was',
      build: () {
        when(() => repository.cancel('2')).thenAnswer(
          (_) async => const Result.err(
            ValidationFailure('This appointment can no longer be cancelled.'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const AppointmentsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppointmentCancelled('2'));
      },
      verify: (bloc) {
        // Showing it as cancelled and then restoring it would leave the
        // patient believing they had cancelled when they had not.
        final untouched =
            bloc.state.appointments.firstWhere((a) => a.id == '2');
        expect(untouched.status, AppointmentStatus.confirmed);
        expect(bloc.state.failure, isA<ValidationFailure>());
        expect(bloc.state.cancellingId, isNull);
      },
    );

    blocTest<AppointmentsBloc, AppointmentsState>(
      'a second cancel is ignored while one is in flight',
      build: () {
        when(() => repository.cancel(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return Result.ok(build('2', AppointmentStatus.cancelled));
        });
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const AppointmentsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppointmentCancelled('2'));
        bloc.add(const AppointmentCancelled('1'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      },
      verify: (_) => verify(() => repository.cancel(any())).called(1),
    );

    blocTest<AppointmentsBloc, AppointmentsState>(
      'reaches ready with a failure even if the repository throws outright',
      build: () {
        when(() => repository.fetchAll()).thenThrow(StateError('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AppointmentsStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, AppointmentsStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );

    test('only a live appointment offers Cancel', () {
      // The server refuses a cancel on a COMPLETED or CANCELLED one, so the
      // action is hidden rather than offered and then rejected.
      expect(build('1', AppointmentStatus.requested).isCancellable, isTrue);
      expect(build('2', AppointmentStatus.confirmed).isCancellable, isTrue);
      expect(build('3', AppointmentStatus.inProgress).isCancellable, isTrue);
      expect(build('4', AppointmentStatus.completed).isCancellable, isFalse);
      expect(build('5', AppointmentStatus.cancelled).isCancellable, isFalse);
    });

    test('a requested appointment is not joinable', () {
      // REQUESTED means no clinician has accepted yet.
      expect(build('1', AppointmentStatus.requested).isJoinable, isFalse);
    });

    test('a confirmed visit is joinable from 10 minutes before until 15 after',
        () {
      final visit = build('2', AppointmentStatus.confirmed);
      final at = visit.scheduledFor;
      expect(visit.isJoinableAt(at.subtract(const Duration(minutes: 11))),
          isFalse);
      expect(visit.isJoinableAt(at.subtract(const Duration(minutes: 10))),
          isTrue);
      expect(visit.isJoinableAt(at.add(const Duration(minutes: 15))), isTrue);
      expect(visit.isJoinableAt(at.add(const Duration(minutes: 16))), isFalse);
      expect(visit.statusLabelAt(at.add(const Duration(minutes: 16))),
          'Missed');
    });

    test('a consultation under way can always be rejoined', () {
      final live = build('3', AppointmentStatus.inProgress);
      expect(live.joinLabelAt(live.scheduledFor.add(const Duration(hours: 2))),
          'Rejoin consultation');
    });
  });
}
