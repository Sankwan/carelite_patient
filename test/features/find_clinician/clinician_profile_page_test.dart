import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/find_clinician/data/clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/booking_request.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_bloc.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_event.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_state.dart';
import 'package:carelite_app/features/find_clinician/presentation/pages/clinician_profile_page.dart';
import 'package:carelite_app/features/find_clinician/presentation/widgets/slot_picker.dart';
import 'package:carelite_app/features/home/domain/money.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockBookingBloc extends MockBloc<BookingEvent, BookingState>
    implements BookingBloc {}

class _MockClinicianRepository extends Mock implements ClinicianRepository {}

/// Registers a clinician search that always offers [others], so the
/// "here are other clinicians" sheet has something to show.
void _offerAlternatives(List<Provider> others) {
  final repository = _MockClinicianRepository();
  registerFallbackValue(const ClinicianFilter());
  when(() => repository.search(any()))
      .thenAnswer((_) async => Result.ok(others));
  GetIt.instance.registerSingleton<ClinicianRepository>(repository);
  addTearDown(GetIt.instance.reset);
}

void main() {
  late _MockBookingBloc bloc;

  const adjei = Provider(
    id: '5',
    kind: ProviderKind.clinician,
    displayName: 'dr_adjei',
    specialty: 'Cardiology',
    rating: 4.8,
    consultationFee: Money(12000),
    isAvailable: true,
    bio: 'Cardiology specialist based in Accra.',
    yearsExperience: 6,
  );

  final tomorrow = DateTime.now().add(const Duration(days: 1));

  setUp(() => bloc = _MockBookingBloc());

  Future<void> pumpPage(WidgetTester tester, BookingState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<BookingBloc>.value(
          value: bloc,
          child: const ClinicianProfileView(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the clinician\'s real details and nothing invented',
      (tester) async {
    await pumpPage(tester, const BookingState(clinician: adjei));

    expect(find.text('dr_adjei'), findsOneWidget);
    expect(find.text('Cardiology'), findsOneWidget);
    expect(find.text('6 years experience'), findsOneWidget);
    expect(find.text('GHS 120'), findsOneWidget);
    expect(find.text('Cardiology specialist based in Accra.'), findsOneWidget);
    // No reviews model and no photos exist on this backend.
    expect(find.textContaining('reviews'), findsNothing);
  });

  testWidgets('says the patient is not being charged now', (tester) async {
    // There is no payments backend, so a fee shown next to a "Book" button
    // must not read as a charge the patient is about to incur.
    await pumpPage(tester, const BookingState(clinician: adjei));

    expect(find.textContaining('not charged now'), findsOneWidget);
  });

  testWidgets('renders only the slots the server returned', (tester) async {
    await pumpPage(tester, BookingState(
      clinician: adjei,
      slots: [tomorrow],
    ));

    expect(find.byType(SlotPicker), findsOneWidget);
  });

  testWidgets('the book button is disabled until a time is chosen',
      (tester) async {
    await pumpPage(tester, BookingState(
      clinician: adjei,
      slots: [tomorrow],
    ));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Book appointment'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the button enables once a slot is selected', (tester) async {
    await pumpPage(tester, BookingState(
      clinician: adjei,
      slots: [tomorrow],
      selectedSlot: tomorrow,
    ));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Book appointment'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Book appointment'));
    await tester.pump();
    verify(() => bloc.add(const BookingSubmitted())).called(1);
  });

  testWidgets('a clinician with no availability offers on demand instead of a '
      'dead end', (tester) async {
    await pumpPage(tester, const BookingState(clinician: adjei));

    expect(find.text('No scheduled times available'), findsOneWidget);
    await tester.tap(find.text('Request on demand'));
    await tester.pump();

    verify(() => bloc.add(const BookingModeChanged(BookingMode.onDemand)))
        .called(1);
  });

  testWidgets('on demand needs no slot, so its button is enabled immediately',
      (tester) async {
    await pumpPage(tester, const BookingState(
      clinician: adjei,
      mode: BookingMode.onDemand,
    ));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Request now'),
    );
    expect(button.onPressed, isNotNull);
    // The time picker is irrelevant to an on-demand request.
    expect(find.byType(SlotPicker), findsNothing);
  });

  testWidgets('shows a spinner in the button while submitting', (tester) async {
    await pumpPage(tester, BookingState(
      status: BookingStatus.submitting,
      clinician: adjei,
      slots: [tomorrow],
      selectedSlot: tomorrow,
    ));

    expect(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  group('when the booking does not go through', () {
    const boateng = Provider(
      id: '8',
      kind: ProviderKind.clinician,
      displayName: 'Dr. Boateng',
      specialty: 'Cardiology',
      isAvailable: true,
    );
    const submitting = BookingState(
      clinician: adjei,
      mode: BookingMode.onDemand,
      status: BookingStatus.submitting,
    );

    testWidgets('a refusal says why and offers other clinicians',
        (tester) async {
      _offerAlternatives([adjei, boateng]);
      whenListen(
        bloc,
        Stream.fromIterable([
          submitting.copyWith(
            status: BookingStatus.ready,
            failure: const ValidationFailure('dr_adjei is not online.'),
          ),
        ]),
        initialState: submitting,
      );
      await pumpPage(tester, submitting);
      await tester.pumpAndSettle();

      expect(find.text('Could not book dr_adjei'), findsOneWidget);
      expect(find.text('dr_adjei is not online.'), findsOneWidget);
      expect(find.text('Dr. Boateng'), findsOneWidget);
    });

    testWidgets('a dropped connection offers a retry that resubmits',
        (tester) async {
      _offerAlternatives([boateng]);
      whenListen(
        bloc,
        Stream.fromIterable([
          submitting.copyWith(
            status: BookingStatus.ready,
            failure: const NetworkFailure(),
          ),
        ]),
        initialState: submitting,
      );
      await pumpPage(tester, submitting);
      await tester.pumpAndSettle();

      expect(find.text('Your connection dropped'), findsOneWidget);
      expect(find.text('Dr. Boateng'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const BookingSubmitted())).called(1);
    });

    testWidgets('slots failing to load is not treated as a refused booking',
        (tester) async {
      _offerAlternatives([boateng]);
      const loading = BookingState(
        clinician: adjei,
        status: BookingStatus.loadingSlots,
      );
      whenListen(
        bloc,
        Stream.fromIterable([
          loading.copyWith(
            status: BookingStatus.ready,
            failure: const NetworkFailure(),
          ),
        ]),
        initialState: loading,
      );
      await pumpPage(tester, loading);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Your connection dropped'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}
