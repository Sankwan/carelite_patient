import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/find_clinician/data/clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/booking_request.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_bloc.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_event.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_state.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicianRepository extends Mock implements ClinicianRepository {}

void main() {
  late _MockClinicianRepository repository;

  const adjei = Provider(
    id: '5',
    kind: ProviderKind.clinician,
    displayName: 'dr_adjei',
    specialty: 'Cardiology',
    rating: 4.8,
    isAvailable: true,
  );

  final tomorrow9 = DateTime.now().add(const Duration(days: 1));
  final tomorrow10 = tomorrow9.add(const Duration(hours: 1));

  final booked = Appointment(
    id: '13',
    provider: adjei,
    scheduledFor: tomorrow9,
    status: AppointmentStatus.requested,
  );

  setUp(() {
    repository = _MockClinicianRepository();
    registerFallbackValue(BookingRequest.any(mode: BookingMode.onDemand));
    when(() => repository.fetchSlots(any(), days: any(named: 'days')))
        .thenAnswer((_) async => Result.ok([tomorrow9, tomorrow10]));
    when(() => repository.book(any()))
        .thenAnswer((_) async => Result.ok(booked));
  });

  BookingBloc buildBloc({Provider? clinician = adjei, BookingMode? mode}) =>
      BookingBloc(
        clinicianRepository: repository,
        clinician: clinician,
        mode: mode ?? BookingMode.scheduled,
      );

  group('BookingBloc — a named clinician', () {
    blocTest<BookingBloc, BookingState>(
      'loads that clinician\'s real slots',
      build: buildBloc,
      act: (bloc) => bloc.add(const BookingStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, BookingStatus.ready);
        expect(bloc.state.slots, [tomorrow9, tomorrow10]);
        verify(() => repository.fetchSlots(5, days: any(named: 'days')))
            .called(1);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'cannot submit a scheduled booking until a time is picked',
      build: buildBloc,
      act: (bloc) => bloc.add(const BookingStarted()),
      skip: 1,
      verify: (bloc) {
        // The button reads this, so a predictable 400 is never how the
        // patient finds out they skipped the time.
        expect(bloc.state.canSubmit, isFalse);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'picking a slot builds a SPECIFIC + SCHEDULED request for it',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const BookingStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(BookingSlotSelected(tomorrow10));
      },
      verify: (bloc) {
        expect(bloc.state.canSubmit, isTrue);
        final request = bloc.state.request;
        expect(request.type, BookingType.specific);
        expect(request.mode, BookingMode.scheduled);
        expect(request.clinicianId, 5);
        expect(request.scheduledFor, tomorrow10);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'switching to on demand drops the chosen slot',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const BookingStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(BookingSlotSelected(tomorrow10));
        bloc.add(const BookingModeChanged(BookingMode.onDemand));
      },
      verify: (bloc) {
        // Keeping it would leave a time highlighted that the request no
        // longer sends — and the server clears scheduled_at for ON_DEMAND.
        expect(bloc.state.selectedSlot, isNull);
        expect(bloc.state.request.scheduledFor, isNull);
        expect(bloc.state.canSubmit, isTrue);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'a clinician with no availability is "no slots", not a failure',
      build: () {
        when(() => repository.fetchSlots(any(), days: any(named: 'days')))
            .thenAnswer((_) async => const Result.ok([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BookingStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.hasNoSlots, isTrue);
        expect(bloc.state.failure, isNull);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'a successful booking reaches booked and carries the appointment',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const BookingStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(BookingSlotSelected(tomorrow9));
        bloc.add(const BookingSubmitted());
      },
      verify: (bloc) {
        expect(bloc.state.status, BookingStatus.booked);
        expect(bloc.state.booked, booked);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'a rejected booking returns to ready and never sets `booked`',
      build: () {
        when(() => repository.book(any())).thenAnswer(
          (_) async => const Result.err(
            ValidationFailure('Required for a SCHEDULED booking.'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const BookingStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(BookingSlotSelected(tomorrow9));
        bloc.add(const BookingSubmitted());
      },
      verify: (bloc) {
        // If `booked` were ever set here, the UI would pop with a success
        // toast for an appointment that does not exist.
        expect(bloc.state.status, BookingStatus.ready);
        expect(bloc.state.booked, isNull);
        expect(bloc.state.failure, isA<ValidationFailure>());
      },
    );

    blocTest<BookingBloc, BookingState>(
      'reaches ready with a failure even if the repository throws outright',
      build: () {
        when(() => repository.fetchSlots(any(), days: any(named: 'days')))
            .thenThrow(StateError('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BookingStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, BookingStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );
  });

  group('BookingBloc — any available clinician', () {
    blocTest<BookingBloc, BookingState>(
      'fetches no slots, because there is no clinician to fetch them for',
      build: () => buildBloc(clinician: null, mode: BookingMode.onDemand),
      act: (bloc) => bloc.add(const BookingStarted()),
      verify: (_) => verifyNever(
        () => repository.fetchSlots(any(), days: any(named: 'days')),
      ),
    );

    blocTest<BookingBloc, BookingState>(
      'submits an ANY + ON_DEMAND request with no clinician id',
      build: () => buildBloc(clinician: null, mode: BookingMode.onDemand),
      act: (bloc) => bloc.add(const BookingSubmitted()),
      verify: (bloc) {
        final request =
            verify(() => repository.book(captureAny())).captured.single
                as BookingRequest;
        expect(request.type, BookingType.any);
        expect(request.mode, BookingMode.onDemand);
        expect(request.clinicianId, isNull);
        // The matched clinician is knowable only from the response.
        expect(bloc.state.booked?.provider.displayName, 'dr_adjei');
      },
    );

    blocTest<BookingBloc, BookingState>(
      'an unmatched request keeps the server\'s reason and stays unbooked',
      build: () {
        when(() => repository.book(any())).thenAnswer(
          (_) async => const Result.err(ValidationFailure(
            'No available certified clinician matched this request.',
          )),
        );
        return buildBloc(clinician: null, mode: BookingMode.onDemand);
      },
      act: (bloc) => bloc.add(const BookingSubmitted()),
      verify: (bloc) {
        expect(bloc.state.booked, isNull);
        expect(
          bloc.state.failure!.message,
          contains('No available certified clinician'),
        );
      },
    );
  });

  test('slots are grouped by calendar day for the picker', () {
    final day1 = DateTime(2026, 9, 10, 9);
    final day1b = DateTime(2026, 9, 10, 10, 30);
    final day2 = DateTime(2026, 9, 11, 9);
    final state = BookingState(slots: [day1, day1b, day2]);

    expect(state.slotsByDay.keys, [DateTime(2026, 9, 10), DateTime(2026, 9, 11)]);
    expect(state.slotsByDay[DateTime(2026, 9, 10)], [day1, day1b]);
  });
}
