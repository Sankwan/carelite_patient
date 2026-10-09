import 'package:equatable/equatable.dart';

import 'clinical_note.dart';
import 'consultation.dart';
import 'discharge_summary.dart';
import 'investigation.dart';
import 'prescription.dart';

/// Everything one consultation holds, assembled client-side.
///
/// It is assembled here because it has to be: every clinical artefact on this
/// backend is consultation-scoped (`/consultations/<id>/summary/`,
/// `/notes/`, `/prescriptions/`, `/investigations/`) and there is no
/// "everything for this patient" endpoint for any of them. Four requests,
/// fired in parallel, for one consultation the patient actually opened —
/// rather than 4×N to render the list.
class MedicalRecord extends Equatable {
  const MedicalRecord({
    required this.consultation,
    this.summary,
    this.note,
    this.prescriptions = const [],
    this.investigations = const [],
  });

  final Consultation consultation;

  /// Null is a real, expected answer: the summary is generated when the
  /// appointment completes, so an open consultation has none (the endpoint
  /// 404s). Null here means "not generated", never "failed to load".
  final DischargeSummary? summary;

  /// The latest version only — earlier versions are history for the
  /// clinician, not the patient.
  final ClinicalNote? note;

  final List<Prescription> prescriptions;
  final List<Investigation> investigations;

  bool get hasAnything =>
      summary != null ||
      note != null ||
      prescriptions.isNotEmpty ||
      investigations.isNotEmpty;

  @override
  List<Object?> get props =>
      [consultation, summary, note, prescriptions, investigations];
}
