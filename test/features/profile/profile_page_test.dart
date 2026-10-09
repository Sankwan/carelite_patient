import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:carelite_app/features/profile/domain/patient_account.dart';
import 'package:carelite_app/features/profile/domain/patient_profile.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_event.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_state.dart';
import 'package:carelite_app/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockProfileBloc bloc;
  late _MockAuthBloc authBloc;

  final account = PatientAccount(
    id: '1',
    username: 'kofi',
    email: 'kofi@example.gh',
    phone: '+233201000000',
    dateOfBirth: DateTime(1990, 3, 12),
    sex: Gender.male,
    bloodGroup: 'O+',
    allergies: 'penicillin',
  );

  setUp(() {
    bloc = _MockProfileBloc();
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthState());
  });

  Future<void> pumpPage(WidgetTester tester, ProfileState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProfileBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const ProfilePage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the stored account details', (tester) async {
    await pumpPage(tester, ProfileState(
      status: ProfileStatus.ready,
      account: account,
    ));

    expect(find.text('kofi'), findsOneWidget);
    expect(find.text('12 Mar 1990'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('penicillin'), findsOneWidget);
    expect(find.text('kofi@example.gh'), findsOneWidget);
  });

  testWidgets('never invents a patient name', (tester) async {
    // This backend has no name field anywhere — username is the only
    // human-readable identifier it exposes.
    await pumpPage(tester, ProfileState(
      status: ProfileStatus.ready,
      account: account,
    ));

    expect(find.text('Full name'), findsNothing);
  });

  testWidgets('says plainly that an emergency contact cannot be stored',
      (tester) async {
    // Complete Profile asks for one, but PatientProfile has only an
    // emergency_flag boolean — no name or phone to save it into.
    await pumpPage(tester, ProfileState(
      status: ProfileStatus.ready,
      account: account,
    ));

    expect(
      find.textContaining('Emergency contact details cannot be stored yet'),
      findsOneWidget,
    );
  });

  testWidgets('an unset field reads "Not set", not blank', (tester) async {
    await pumpPage(tester, const ProfileState(
      status: ProfileStatus.ready,
      account: PatientAccount(id: '1', username: 'kofi'),
    ));

    expect(find.text('Not set'), findsWidgets);
    expect(find.text('None recorded'), findsOneWidget);
  });

  testWidgets('sign out stays reachable even when the profile failed to load',
      (tester) async {
    await pumpPage(tester, const ProfileState(
      status: ProfileStatus.ready,
      failure: NetworkFailure(),
    ));

    expect(find.text('Could not load your profile'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('signing out asks first', (tester) async {
    await pumpPage(tester, ProfileState(
      status: ProfileStatus.ready,
      account: account,
    ));

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    verifyNever(() => authBloc.add(const AuthSignOutRequested()));

    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    verify(() => authBloc.add(const AuthSignOutRequested())).called(1);
  });
}
