import '../../../core/utils/result.dart';
import '../domain/consultation.dart';
import '../domain/medical_record.dart';

abstract class RecordsRepository {
  /// The patient's consultations, newest first. Scoped to "mine"
  /// server-side, so there is no patient id to pass.
  Future<Result<List<Consultation>>> fetchConsultations();

  /// One consultation by id — what a notification points at
  /// (`RESULT_READY` carries `consultation_id`).
  Future<Result<Consultation>> fetchConsultation(String id);

  /// Everything attached to one consultation.
  ///
  /// A section that legitimately has no data comes back empty (or null for
  /// the summary) rather than as a failure — the screen must be able to tell
  /// "none" from "did not load".
  Future<Result<MedicalRecord>> fetchRecord(Consultation consultation);
}
