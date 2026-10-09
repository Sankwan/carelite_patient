import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/medical_records/data/django_records_repository.dart';
import 'package:carelite_app/features/medical_records/domain/consultation.dart';
import 'package:carelite_app/features/medical_records/domain/investigation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

const _consultation = Consultation(
  id: '4',
  appointmentId: '5',
  status: ConsultationStatus.closed,
  clinicianUsername: 'dr_adjei',
  latestNoteVersion: 1,
);

void main() {
  late _MockApiClient client;
  late DjangoRecordsRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoRecordsRepository(client);

    // Default: every section empty, overridden per test.
    when(() => client.get(ApiContract.consultationSummary('4')))
        .thenAnswer((_) async => _response(404, {'detail': 'No summary…'}));
    when(() => client.get(ApiContract.consultationNotes('4')))
        .thenAnswer((_) async => _response(200, {'results': <dynamic>[]}));
    when(() => client.get(ApiContract.consultationPrescriptions('4')))
        .thenAnswer((_) async => _response(200, {'results': <dynamic>[]}));
    when(() => client.get(ApiContract.consultationInvestigations('4')))
        .thenAnswer((_) async => _response(200, {'results': <dynamic>[]}));
  });

  group('fetchConsultations', () {
    test('parses the envelope and orders newest first', () async {
      when(() => client.get(ApiContract.consultations)).thenAnswer(
        (_) async => _response(200, {
          'results': [
            {
              'id': 1, 'appointment': 1, 'status': 'CLOSED',
              'clinician_username': 'dr_adjei',
              'started_at': '2026-01-01T09:00:00Z',
              'ended_at': '2026-01-01T09:30:00Z',
              'latest_note_version': 1,
            },
            {
              'id': 2, 'appointment': 2, 'status': 'CLOSED',
              'clinician_username': 'dr_owusu',
              'started_at': '2026-06-01T09:00:00Z',
              'ended_at': '2026-06-01T09:30:00Z',
              'latest_note_version': 0,
            },
          ],
        }),
      );

      final result = await repository.fetchConsultations();

      final list = result.when(ok: (v) => v, err: (f) => throw f);
      // The endpoint has no ?ordering=; server order would look arbitrary.
      expect(list.map((c) => c.id), ['2', '1']);
      expect(list.first.hasNote, isFalse);
      expect(list.last.hasNote, isTrue);
    });

    test('a consultation with no dates sorts last instead of crashing',
        () async {
      when(() => client.get(ApiContract.consultations)).thenAnswer(
        (_) async => _response(200, {
          'results': [
            {
              'id': 1, 'appointment': 1, 'status': 'OPEN',
              'started_at': null, 'ended_at': null,
            },
            {
              'id': 2, 'appointment': 2, 'status': 'CLOSED',
              'started_at': '2026-06-01T09:00:00Z',
              'ended_at': '2026-06-01T09:30:00Z',
            },
          ],
        }),
      );

      final result = await repository.fetchConsultations();

      final list = result.when(ok: (v) => v, err: (f) => throw f);
      expect(list.map((c) => c.id), ['2', '1']);
      expect(list.last.dateLabel, 'Date unknown');
      expect(list.last.clinicianLabel, 'Clinician unavailable');
    });

    test('a malformed row is a visible failure, never an uncaught throw',
        () async {
      when(() => client.get(ApiContract.consultations)).thenAnswer(
        (_) async => _response(200, {
          'results': [
            {'id': 1, 'appointment': 1, 'status': 'CLOSED',
             'latest_note_version': 'not-an-int'},
          ],
        }),
      );

      final result = await repository.fetchConsultations();

      expect(result.when(ok: (_) => null, err: (f) => f), isNotNull);
    });
  });

  group('fetchRecord', () {
    test('a 404 summary means "not generated yet", not a failure', () async {
      // The summary is generated when the appointment completes, so an open
      // consultation legitimately has none — and the endpoint 404s for it.
      final result = await repository.fetchRecord(_consultation);

      final record = result.when(ok: (v) => v, err: (f) => throw f);
      expect(record.summary, isNull);
      expect(record.hasAnything, isFalse);
    });

    test('reads the summary, latest note, prescriptions and results', () async {
      when(() => client.get(ApiContract.consultationSummary('4'))).thenAnswer(
        (_) async => _response(200, {
          'id': 2,
          'diagnosis': 'Suspected stable angina',
          'advice': 'Avoid heavy exertion.',
          'prescriptions': 'Aspirin 75mg daily',
          'follow_up_date': '2026-09-07',
          'generated_by_username': 'dr_adjei',
          'generated_at': '2026-09-02T08:25:48Z',
        }),
      );
      when(() => client.get(ApiContract.consultationNotes('4'))).thenAnswer(
        (_) async => _response(200, {
          'results': [
            {
              'id': 3, 'version': 1, 'author_username': 'dr_adjei',
              'created_at': '2026-09-02T08:25:48Z',
              'chief_complaint': 'Chest tightness on exertion',
              'assessment': 'Suspected stable angina',
              // Blank fields must not become empty headings.
              'family_history': '', 'social_history': '', 'free_text': '',
            },
          ],
        }),
      );
      when(() => client.get(ApiContract.consultationPrescriptions('4')))
          .thenAnswer((_) async => _response(200, {
                'results': [
                  {
                    'id': 2, 'consultation': 4,
                    'prescriber_name': 'Kwame Adjei',
                    'assigned_pharmacy': {
                      'id': 10, 'name': 'Circle Pharmacy', 'address': 'Circle',
                    },
                    'items': [
                      {
                        'id': 1, 'drug_name': 'Aspirin 75mg',
                        'dosage': '75mg', 'frequency': 'daily',
                        'duration': '', 'notes': '',
                      },
                    ],
                    'signed_at': '2026-09-02T08:25:48Z',
                  },
                ],
              }));
      when(() => client.get(ApiContract.consultationInvestigations('4')))
          .thenAnswer((_) async => _response(200, {
                'results': [
                  {
                    'id': 3, 'consultation': 4, 'type': 'LAB',
                    'test_name': 'Lipid Profile', 'priority': 'URGENT',
                    'reason': 'Assess cardiovascular risk',
                    'status': 'RESULT_UPLOADED',
                    'assigned_facility': {
                      'id': 7, 'name': 'Circle Diagnostics',
                      'address': 'Kwame Nkrumah Circle',
                      // The live FacilitySerializer shape.
                      'phone': '+233302000111', 'lat': 5.5717,
                      'lng': -0.2107,
                      'operating_hours': 'Mon-Fri 08:00-18:00',
                    },
                    'result': {
                      'id': 2,
                      'result_text': 'Total chol 6.2 mmol/L (high)',
                      'file': null,
                      'uploaded_at': '2026-09-02T08:25:48Z',
                    },
                  },
                ],
              }));

      final result = await repository.fetchRecord(_consultation);

      final record = result.when(ok: (v) => v, err: (f) => throw f);
      expect(record.summary!.diagnosis, 'Suspected stable angina');
      expect(record.summary!.followUpLabel, '7 Sep 2026');
      // Empty note fields are dropped, not rendered as blank headings.
      expect(record.note!.sections.keys,
          ['Chief complaint', 'Assessment']);
      expect(record.prescriptions.single.items.single.instructions,
          '75mg · daily');
      expect(record.prescriptions.single.pharmacy?.name, 'Circle Pharmacy');
      // A facility with no phone or coordinates offers neither action.
      expect(record.prescriptions.single.pharmacy?.hasPhone, isFalse);
      expect(record.prescriptions.single.pharmacy?.hasLocation, isFalse);
      final lab = record.investigations.single.facility!;
      expect(lab.phone, '+233302000111');
      expect(lab.latitude, 5.5717);
      expect(lab.longitude, -0.2107);
      expect(lab.operatingHours, 'Mon-Fri 08:00-18:00');
      expect(record.investigations.single.status,
          InvestigationStatus.resultUploaded);
      expect(record.investigations.single.hasResult, isTrue);
      expect(record.hasAnything, isTrue);
    });

    test('shows the latest note version, not the clinician\'s edit history',
        () async {
      when(() => client.get(ApiContract.consultationNotes('4'))).thenAnswer(
        (_) async => _response(200, {
          'results': [
            {'id': 1, 'version': 1, 'chief_complaint': 'First draft'},
            {'id': 2, 'version': 2, 'chief_complaint': 'Corrected'},
          ],
        }),
      );

      final result = await repository.fetchRecord(_consultation);

      final record = result.when(ok: (v) => v, err: (f) => throw f);
      expect(record.note!.version, 2);
      expect(record.note!.sections['Chief complaint'], 'Corrected');
    });

    test('a note with every field blank is treated as no note', () async {
      when(() => client.get(ApiContract.consultationNotes('4'))).thenAnswer(
        (_) async => _response(200, {
          'results': [
            {'id': 1, 'version': 1, 'chief_complaint': '', 'plan': '   '},
          ],
        }),
      );

      final result = await repository.fetchRecord(_consultation);

      // A card of empty headings reads as a broken screen.
      expect(result.when(ok: (r) => r.note, err: (f) => throw f), isNull);
    });

    test('one failing section does not fail the whole record', () async {
      // A patient who can see their diagnosis and prescription is better
      // served than one shown a full-screen error because investigations
      // 403'd.
      when(() => client.get(ApiContract.consultationInvestigations('4')))
          .thenAnswer((_) async => _response(403, {'detail': 'Denied'}));
      when(() => client.get(ApiContract.consultationSummary('4'))).thenAnswer(
        (_) async => _response(200, {'id': 2, 'diagnosis': 'Angina'}),
      );

      final result = await repository.fetchRecord(_consultation);

      final record = result.when(ok: (v) => v, err: (f) => throw f);
      expect(record.summary!.diagnosis, 'Angina');
      expect(record.investigations, isEmpty);
    });
  });
}
