import 'package:carelite_app/core/utils/external_launcher.dart';
import 'package:carelite_app/features/medical_records/domain/care_facility.dart';
import 'package:carelite_app/features/medical_records/presentation/widgets/facility_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class _FakeLauncher implements ExternalLauncher {
  _FakeLauncher({this.succeeds = true});

  final bool succeeds;
  final List<String> calls = [];

  @override
  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    calls.add('directions:$latitude,$longitude');
    return succeeds;
  }

  @override
  Future<bool> dial(String phone) async {
    calls.add('dial:$phone');
    return succeeds;
  }
}

void main() {
  const full = CareFacility(
    name: 'Circle Diagnostics',
    address: 'Kwame Nkrumah Circle',
    phone: '+233302000111',
    latitude: 5.5717,
    longitude: -0.2107,
    operatingHours: 'Mon-Fri 08:00-18:00',
  );

  late _FakeLauncher launcher;

  setUp(() {
    launcher = _FakeLauncher();
    GetIt.instance.registerSingleton<ExternalLauncher>(launcher);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> pump(WidgetTester tester, CareFacility facility) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FacilityCard(heading: 'Test at', facility: facility),
        ),
      ),
    );
  }

  testWidgets('shows where to go and offers directions and a call',
      (tester) async {
    await pump(tester, full);

    expect(find.text('Circle Diagnostics'), findsOneWidget);
    expect(find.text('Kwame Nkrumah Circle'), findsOneWidget);
    expect(find.text('Mon-Fri 08:00-18:00'), findsOneWidget);

    await tester.tap(find.text('Directions'));
    await tester.tap(find.text('Call'));
    await tester.pump();

    expect(launcher.calls, ['directions:5.5717,-0.2107', 'dial:+233302000111']);
  });

  testWidgets('offers no button it has no data for', (tester) async {
    // The server allows a facility with a blank phone; a Call button that
    // dialled nothing would be worse than no button.
    await pump(tester, const CareFacility(name: 'Circle Pharmacy'));

    expect(find.text('Circle Pharmacy'), findsOneWidget);
    expect(find.text('Directions'), findsNothing);
    expect(find.text('Call'), findsNothing);
  });

  testWidgets('a phone with no dialler is told the number instead',
      (tester) async {
    await GetIt.instance.unregister<ExternalLauncher>();
    GetIt.instance
        .registerSingleton<ExternalLauncher>(_FakeLauncher(succeeds: false));
    await pump(tester, full);

    await tester.tap(find.text('Call'));
    // The toast is inserted a frame after the launcher's future resolves.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.textContaining('+233302000111'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  test('blank strings from the server become "not provided"', () {
    final facility = CareFacility.fromDjangoJson({
      'name': 'Osu Pharmacy', 'address': '', 'phone': '  ',
      'lat': 5.55, 'lng': -0.18, 'operating_hours': '',
    })!;

    expect(facility.address, isNull);
    expect(facility.hasPhone, isFalse);
    expect(facility.hasLocation, isTrue);
  });
}
