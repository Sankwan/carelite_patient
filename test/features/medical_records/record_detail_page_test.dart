import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/medical_records/domain/care_facility.dart';
import 'package:carelite_app/features/medical_records/domain/clinical_note.dart';
import 'package:carelite_app/features/medical_records/domain/consultation.dart';
import 'package:carelite_app/features/medical_records/domain/discharge_summary.dart';
import 'package:carelite_app/features/medical_records/domain/investigation.dart';
import 'package:carelite_app/features/medical_records/domain/medical_record.dart';
import 'package:carelite_app/features/medical_records/domain/prescription.dart';
import 'package:carelite_app/features/medical_records/presentation/bloc/records_bloc.dart';
import 'package:carelite_app/features/medical_records/presentation/bloc/records_event.dart';
import 'package:carelite_app/features/medical_records/presentation/bloc/records_state.dart';
import 'package:carelite_app/features/medical_records/presentation/pages/record_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecordDetailBloc extends MockBloc<RecordsEvent, RecordDetailState>
    implements RecordDetailBloc {}

void main() {
  late _MockRecordDetailBloc bloc;

  const closed = Consultation(
    id: '4',
    appointmentId: '5',
    status: ConsultationStatus.closed,
    clinicianUsername: 'dr_adjei',
    latestNoteVersion: 1,
  );
  const open = Consultation(
    id: '5',
    appointmentId: '6',
    status: ConsultationStatus.open,
    clinicianUsername: 'dr_adjei',
  );

  setUp(() => bloc = _MockRecordDetailBloc());

  Future<void> pumpPage(WidgetTester tester, RecordDetailState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RecordDetailBloc>.value(
          value: bloc,
          child: const RecordDetailView(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a spinner while the four calls are in flight',
      (tester) async {
    await pumpPage(tester, const RecordDetailState(consultation: closed));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders every section that has data', (tester) async {
    await pumpPage(tester, const RecordDetailState(
      consultation: closed,
      status: RecordDetailStatus.ready,
      record: MedicalRecord(
        consultation: closed,
        summary: DischargeSummary(
          id: '2',
          diagnosis: 'Suspected stable angina',
          advice: 'Avoid heavy exertion.',
        ),
        note: ClinicalNote(
          id: '3',
          version: 1,
          sections: {'Chief complaint': 'Chest tightness on exertion'},
        ),
        prescriptions: [
          Prescription(
            id: '2',
            prescriberName: 'Kwame Adjei',
            pharmacy: CareFacility(name: 'Circle Pharmacy'),
            items: [
              PrescriptionItem(
                drugName: 'Aspirin 75mg',
                dosage: '75mg',
                frequency: 'daily',
              ),
            ],
          ),
        ],
        investigations: [
          Investigation(
            id: '3',
            testName: 'Lipid Profile',
            status: InvestigationStatus.resultUploaded,
            resultText: 'Total chol 6.2 mmol/L (high)',
            facility: CareFacility(name: 'Circle Diagnostics'),
          ),
        ],
      ),
    ));

    expect(find.text('Suspected stable angina'), findsOneWidget);
    expect(find.text('Chest tightness on exertion'), findsOneWidget);
    expect(find.text('Aspirin 75mg'), findsOneWidget);
    expect(find.text('75mg · daily'), findsOneWidget);
    // Once in Prescriptions, once under "Shared with".
    expect(find.textContaining('Circle Pharmacy'), findsNWidgets(2));
    // In Tests & results, and as the reason it went to the lab in "Shared with".
    expect(find.text('Lipid Profile'), findsNWidgets(2));
    expect(find.text('Total chol 6.2 mmol/L (high)'), findsOneWidget);
  });

  testWidgets('an empty section says so instead of disappearing',
      (tester) async {
    // The patient must be able to tell "no prescription was issued" from
    // "the prescriptions did not load".
    await pumpPage(tester, const RecordDetailState(
      consultation: closed,
      status: RecordDetailStatus.ready,
      record: MedicalRecord(consultation: closed),
    ));

    expect(find.text('Prescriptions'), findsOneWidget);
    expect(find.text('No medication was prescribed at this visit.'),
        findsOneWidget);
    expect(find.text('No tests were ordered at this visit.'), findsOneWidget);
  });

  testWidgets('an open consultation explains that a summary comes later',
      (tester) async {
    // The summary is generated on completion, so its absence here is normal
    // — not a missing record.
    await pumpPage(tester, const RecordDetailState(
      consultation: open,
      status: RecordDetailStatus.ready,
      record: MedicalRecord(consultation: open),
    ));

    expect(
      find.text('A summary is written when the consultation is completed.'),
      findsOneWidget,
    );
  });

  testWidgets('a result file is acknowledged, not offered as a broken link',
      (tester) async {
    await pumpPage(tester, const RecordDetailState(
      consultation: closed,
      status: RecordDetailStatus.ready,
      record: MedicalRecord(
        consultation: closed,
        investigations: [
          Investigation(
            id: '3',
            testName: 'Chest X-ray',
            status: InvestigationStatus.resultUploaded,
            hasResultFile: true,
          ),
        ],
      ),
    ));

    expect(find.textContaining('once CareLite can show attachments'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry rather than a blank page',
      (tester) async {
    await pumpPage(tester, const RecordDetailState(
      consultation: closed,
      status: RecordDetailStatus.ready,
      failure: NetworkFailure(),
    ));

    expect(find.text('Could not open this record'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    verify(() => bloc.add(const RecordOpened(closed))).called(1);
  });
}
