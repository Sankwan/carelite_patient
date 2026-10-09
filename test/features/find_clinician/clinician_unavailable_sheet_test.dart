import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/find_clinician/data/clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/find_clinician/presentation/widgets/clinician_unavailable_sheet.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicianRepository extends Mock implements ClinicianRepository {}

Provider _clinician(String id, String name, {String specialty = 'Cardiology'}) {
  return Provider(
    id: id,
    kind: ProviderKind.clinician,
    displayName: name,
    specialty: specialty,
    isAvailable: true,
  );
}

void main() {
  final adjei = _clinician('6', 'Dr. Adjei');
  final boateng = _clinician('8', 'Dr. Boateng');
  final owusu = _clinician('7', 'Dr. Owusu', specialty: 'Dermatology');

  group('loadClinicianAlternatives', () {
    late _MockClinicianRepository repository;

    setUp(() {
      repository = _MockClinicianRepository();
      registerFallbackValue(const ClinicianFilter());
    });

    void stub(ClinicianFilter filter, List<Provider> clinicians) {
      when(() => repository.search(filter))
          .thenAnswer((_) async => Result.ok(clinicians));
    }

    test('prefers someone online with the same specialty, and never offers '
        'the clinician who was unavailable', () async {
      stub(const ClinicianFilter(specialty: 'Cardiology', onlineOnly: true),
          [adjei, boateng]);

      final found = await loadClinicianAlternatives(
        repository,
        excludeClinicianId: '6',
        specialty: 'Cardiology',
      );

      expect(found.clinicians, [boateng]);
      expect(found.onlineNow, isTrue);
    });

    test('falls back to anyone online when the specialty has nobody else',
        () async {
      stub(const ClinicianFilter(specialty: 'Cardiology', onlineOnly: true),
          [adjei]);
      stub(const ClinicianFilter(onlineOnly: true), [adjei, owusu]);

      final found = await loadClinicianAlternatives(
        repository,
        excludeClinicianId: '6',
        specialty: 'Cardiology',
      );

      expect(found.clinicians, [owusu]);
      expect(found.onlineNow, isTrue);
    });

    test('says so when nobody is online, and offers clinicians to book a '
        'time with instead', () async {
      stub(const ClinicianFilter(specialty: 'Cardiology', onlineOnly: true),
          []);
      stub(const ClinicianFilter(onlineOnly: true), []);
      stub(const ClinicianFilter(specialty: 'Cardiology'), [adjei, boateng]);

      final found = await loadClinicianAlternatives(
        repository,
        excludeClinicianId: '6',
        specialty: 'Cardiology',
      );

      expect(found.clinicians, [boateng]);
      expect(found.onlineNow, isFalse);
    });

    test('a failed lookup is "none found", not a second error', () async {
      when(() => repository.search(any()))
          .thenAnswer((_) async => const Result.err(NetworkFailure()));

      final found = await loadClinicianAlternatives(repository);

      expect(found.clinicians, isEmpty);
    });
  });

  group('sheet', () {
    Future<UnavailableChoice?> Function() open(
      WidgetTester tester, {
      String? retryLabel,
      bool suggestOthers = true,
      List<Provider> clinicians = const [],
    }) {
      UnavailableChoice? choice;
      var closed = false;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      return () async {
        if (!closed) {
          await tester.pumpWidget(MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  choice = await showClinicianUnavailableSheet(
                    context,
                    title: 'Dr. Adjei can\'t take the call right now',
                    message: 'You can speak to another clinician instead.',
                    retryLabel: retryLabel,
                    suggestOthers: suggestOthers,
                    loader: () async => ClinicianAlternatives(
                      clinicians: clinicians,
                      onlineNow: true,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          closed = true;
          return null;
        }
        await tester.pumpAndSettle();
        return choice;
      };
    }

    testWidgets('says what happened and returns the clinician picked',
        (tester) async {
      final step = open(tester, clinicians: [boateng]);
      await step();

      expect(find.text('Dr. Adjei can\'t take the call right now'),
          findsOneWidget);
      expect(find.text('Available now'), findsOneWidget);

      await tester.tap(find.text('Dr. Boateng'));
      final choice = await step();

      expect(choice, isA<UnavailablePicked>());
      expect((choice! as UnavailablePicked).clinician, boateng);
    });

    testWidgets('a connection problem offers a retry and no clinician list',
        (tester) async {
      final step = open(
        tester,
        retryLabel: 'Try again',
        suggestOthers: false,
        clinicians: [boateng],
      );
      await step();

      expect(find.text('Dr. Boateng'), findsNothing);

      await tester.tap(find.text('Try again'));
      expect(await step(), isA<UnavailableRetry>());
    });

    testWidgets('the patient can decline every suggestion', (tester) async {
      final step = open(tester, clinicians: [boateng]);
      await step();

      await tester.tap(find.text('Not now'));
      expect(await step(), isNull);
    });

    testWidgets('says plainly when there is nobody else', (tester) async {
      final step = open(tester);
      await step();

      expect(
        find.textContaining('No other clinicians are available'),
        findsOneWidget,
      );
    });
  });
}
