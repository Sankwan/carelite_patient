import 'package:carelite_app/core/storage/app_preferences.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/location/data/location_repository.dart';
import 'package:carelite_app/features/location/presentation/bloc/location_bloc.dart';
import 'package:carelite_app/features/location/presentation/pages/enable_location_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  late _MockLocationRepository locationRepository;
  late AppPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    locationRepository = _MockLocationRepository();
    preferences = await AppPreferences.resolve();
  });

  Widget buildSubject() {
    return BlocProvider<LocationBloc>(
      create: (_) => LocationBloc(
        locationRepository: locationRepository,
        preferences: preferences,
      ),
      child: const MaterialApp(home: EnableLocationPage()),
    );
  }

  testWidgets('uses the corrected brand name and disclaimer copy',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Enable Location Access'), findsOneWidget);

    // The Figma frame reads "Car Lite Health" — a typo, not a brand variant.
    expect(
      find.textContaining('CareLite Health uses your location'),
      findsOneWidget,
    );
    expect(find.textContaining('Car Lite Health'), findsNothing);

    // ...and replaces "we cant help you as much" with real grammar.
    expect(
      find.textContaining('You can still browse the app without location'),
      findsOneWidget,
    );
    expect(find.textContaining('cant help you'), findsNothing);

    expect(find.text('Allow Location Access'), findsOneWidget);
    expect(find.text('Maybe Later'), findsOneWidget);
  });

  testWidgets('offers a settings route instead of a dead end when access is '
      'permanently denied', (tester) async {
    when(() => locationRepository.requestPermission()).thenAnswer(
      (_) async => const Result.ok(LocationAccess.deniedForever),
    );

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Allow Location Access'));
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Continue without location'), findsOneWidget);
  });
}
