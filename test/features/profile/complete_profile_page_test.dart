import 'package:carelite_app/features/auth/data/auth_repository.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:carelite_app/features/profile/data/profile_repository.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_setup_bloc.dart';
import 'package:carelite_app/features/profile/presentation/pages/complete_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Renders the screen the signup funnel cannot be driven to by hand
/// without a live Supabase project, so its layout and the "Finish Setup"
/// gating are still covered.
void main() {
  late _MockProfileRepository profileRepository;
  late _MockAuthRepository authRepository;

  setUp(() {
    profileRepository = _MockProfileRepository();
    authRepository = _MockAuthRepository();
    when(() => authRepository.authStateChanges())
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepository: authRepository),
        ),
        BlocProvider<ProfileSetupBloc>(
          create: (_) => ProfileSetupBloc(profileRepository: profileRepository),
        ),
      ],
      child: const MaterialApp(home: CompleteProfilePage()),
    );
  }

  /// The screen is taller than the default 800x600 test viewport, and a
  /// CustomScrollView does not build slivers that are off-screen — so the
  /// surface is sized to a real phone before pumping.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildSubject());
    await tester.pump();
  }

  testWidgets('renders both form sections and the Figma copy', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('This helps us personalise your care'), findsOneWidget);
    expect(find.text('PERSONAL INFO'), findsOneWidget);
    expect(find.text('EMERGENCY CONTACT'), findsOneWidget);
    expect(find.text('Finish Setup'), findsOneWidget);
  });

  testWidgets('offers every gender and blood type choice', (tester) async {
    await pumpScreen(tester);

    for (final label in ['Female', 'Male', 'Prefer not to say']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('keeps Finish Setup disabled until the required fields are filled',
      (tester) async {
    await pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Finish Setup'),
        matching: find.byType(ElevatedButton),
      ),
    );
    // Name and date of birth are both still empty.
    expect(button.onPressed, isNull);
  });

  testWidgets('never lets a date of birth be set in the future',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Select your date of birth'));
    await tester.pumpAndSettle();

    // Assert on the picker's own bound rather than on rendered day numbers:
    // a future day can still be painted in the grid while being unselectable.
    // This is the guard the Figma mock (which prefilled 08/30/2026) lacks.
    final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    final endOfToday = DateUtils.dateOnly(DateTime.now());
    expect(dialog.lastDate.isAfter(endOfToday), isFalse);
  });
}
