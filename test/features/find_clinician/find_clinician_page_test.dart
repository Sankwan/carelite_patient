import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_bloc.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_event.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/booking_state.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/find_clinician_bloc.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/find_clinician_event.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/find_clinician_state.dart';
import 'package:carelite_app/features/find_clinician/presentation/pages/find_clinician_page.dart';
import 'package:carelite_app/features/find_clinician/presentation/widgets/match_me_card.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:carelite_app/features/home/presentation/widgets/provider_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFindClinicianBloc
    extends MockBloc<FindClinicianEvent, FindClinicianState>
    implements FindClinicianBloc {}

class _MockBookingBloc extends MockBloc<BookingEvent, BookingState>
    implements BookingBloc {}

void main() {
  late _MockFindClinicianBloc bloc;
  late _MockBookingBloc booking;

  const adjei = Provider(
    id: '5',
    kind: ProviderKind.clinician,
    displayName: 'dr_adjei',
    specialty: 'Cardiology',
    rating: 4.8,
    isAvailable: true,
  );

  setUp(() {
    bloc = _MockFindClinicianBloc();
    booking = _MockBookingBloc();
    when(() => booking.state).thenReturn(const BookingState());
  });

  Future<void> pumpPage(
    WidgetTester tester,
    FindClinicianState state, {
    ClinicianSearchMode mode = ClinicianSearchMode.general,
  }) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<FindClinicianBloc>.value(value: bloc),
            BlocProvider<BookingBloc>.value(value: booking),
          ],
          // FindClinicianView is exactly what the real page renders inside
          // its own BlocProvider, so this exercises the shipping tree.
          child: FindClinicianView(mode: mode),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('General Care offers only availability — no specialty chips '
      'or specialty search', (tester) async {
    // No clinicians listed, so a specialty's text can only come from a chip,
    // not from a card's own specialty label.
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
    ));

    expect(find.text('Find a Clinician'), findsOneWidget);
    expect(find.text('Available now'), findsOneWidget);
    for (final specialty in kSpecialistChips) {
      expect(find.text(specialty), findsNothing);
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(MatchMeCard), findsOneWidget);
  });

  testWidgets('Find Specialists offers specialty chips and asks for a pick '
      'before listing anyone', (tester) async {
    await pumpPage(
      tester,
      const FindClinicianState(
        status: FindClinicianStatus.ready,
        clinicians: [adjei],
      ),
      mode: ClinicianSearchMode.specialists,
    );

    expect(find.text('Find Specialists'), findsOneWidget);
    expect(find.text('Clinical Psychology'), findsOneWidget);
    expect(find.text('Physiotherapy'), findsOneWidget);
    // An unfiltered list would include general practitioners under a
    // "specialists" title — the backend can't exclude them.
    expect(find.text('Choose a specialty'), findsOneWidget);
    expect(find.byType(ProviderCard), findsNothing);
    // Match Me books anyone free, regardless of specialty.
    expect(find.byType(MatchMeCard), findsNothing);
  });

  testWidgets('Find Specialists lists results once a specialty is chosen',
      (tester) async {
    await pumpPage(
      tester,
      const FindClinicianState(
        status: FindClinicianStatus.ready,
        clinicians: [adjei],
        filter: ClinicianFilter(specialty: 'Cardiology'),
      ),
      mode: ClinicianSearchMode.specialists,
    );

    expect(find.byType(ProviderCard), findsOneWidget);
    expect(find.text('Choose a specialty'), findsNothing);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpPage(tester, const FindClinicianState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('lists the clinicians the server returned', (tester) async {
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
      clinicians: [adjei],
    ));

    expect(find.byType(ProviderCard), findsOneWidget);
    expect(find.text('dr_adjei'), findsOneWidget);
    expect(find.textContaining('highest rated first'), findsOneWidget);
  });

  testWidgets('never shows a distance on a clinician', (tester) async {
    // ClinicianProfile carries no lat/lng at all, so any distance would be
    // invented. The sort chips for it are absent for the same reason.
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
      clinicians: [adjei],
    ));

    expect(find.textContaining(' km'), findsNothing);
    expect(find.text('Nearest'), findsNothing);
    expect(find.text('Lowest fee'), findsNothing);
  });

  testWidgets('offers the match action', (tester) async {
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
      clinicians: [adjei],
    ));

    expect(find.byType(MatchMeCard), findsOneWidget);
    await tester.tap(find.byTooltip('Match me with any available clinician'));
    await tester.pump();

    verify(() => booking.add(const BookingSubmitted())).called(1);
  });

  testWidgets('an empty filtered result offers to clear the filters, not an '
      'error', (tester) async {
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
      filter: ClinicianFilter(specialty: 'Neurology'),
    ));

    expect(find.text('No clinicians match those filters'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();

    verify(() => bloc.add(const FindClinicianFiltersCleared())).called(1);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
      failure: NetworkFailure(),
    ));

    expect(find.text('Could not load clinicians'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    verify(() => bloc.add(const FindClinicianRetried())).called(1);
  });

  testWidgets('an empty or failed list is still pull-to-refreshable',
      (tester) async {
    await pumpPage(tester, const FindClinicianState(
      status: FindClinicianStatus.ready,
      failure: NetworkFailure(),
    ));

    // A Column here would make the refresh gesture inert, leaving the
    // patient with no way to retry by pulling.
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });
}
