import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/clinical_note.dart';
import '../domain/consultation.dart';
import '../domain/discharge_summary.dart';
import '../domain/investigation.dart';
import '../domain/medical_record.dart';
import '../domain/prescription.dart';
import 'records_repository.dart';

/// Medical records against the Django API.
///
/// Verified live against the seeded patient `kofi`, who has a real closed
/// consultation with a discharge summary, a versioned clinical note, a
/// prescription (with items and an assigned pharmacy) and a lab
/// investigation with an uploaded result.
class DjangoRecordsRepository implements RecordsRepository {
  const DjangoRecordsRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Consultation>>> fetchConsultations() async {
    try {
      final response = await _client.getAllPages(ApiContract.consultations);
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      try {
        final consultations = results
            .cast<Map<String, dynamic>>()
            .map(Consultation.fromDjangoJson)
            .toList()
          // Newest first. The endpoint has no ?ordering=, and a records list
          // in server order would look arbitrary to a patient.
          ..sort((a, b) {
            final aDate = a.occurredAt;
            final bDate = b.occurredAt;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
        return Result.ok(List.unmodifiable(consultations));
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read your records (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<Consultation>> fetchConsultation(String id) async {
    try {
      final response = await _client.get(ApiContract.consultation(id));
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      try {
        return Result.ok(Consultation.fromDjangoJson(
          (response.data as Map).cast<String, dynamic>(),
        ));
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read this record (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<MedicalRecord>> fetchRecord(Consultation consultation) async {
    try {
      // In parallel: four sequential round trips on a Ghanaian mobile
      // connection is the difference between a record that opens and one the
      // patient backs out of.
      final responses = await Future.wait([
        _client.get(ApiContract.consultationSummary(consultation.id)),
        _client.get(ApiContract.consultationNotes(consultation.id)),
        _client.get(ApiContract.consultationPrescriptions(consultation.id)),
        _client.get(ApiContract.consultationInvestigations(consultation.id)),
      ]);

      try {
        return Result.ok(MedicalRecord(
          consultation: consultation,
          summary: _summaryFrom(responses[0]),
          note: _latestNoteFrom(responses[1]),
          prescriptions: _listFrom(responses[2], Prescription.fromDjangoJson),
          investigations: _listFrom(responses[3], Investigation.fromDjangoJson),
        ));
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read this record (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  /// 404 here means "no summary has been generated yet" — the server's own
  /// wording — which is the normal state of an open consultation, not an
  /// error. Mapped to null on this endpoint only, and only for 404.
  DischargeSummary? _summaryFrom(Response<dynamic> response) {
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200 || response.data is! Map) return null;
    return DischargeSummary.fromDjangoJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  /// Notes come back newest-first and versioned; the patient sees the
  /// current one, not the clinician's edit history.
  ClinicalNote? _latestNoteFrom(Response<dynamic> response) {
    final rows = _rowsFrom(response);
    if (rows.isEmpty) return null;
    final notes = rows.map(ClinicalNote.fromDjangoJson).toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    final latest = notes.first;
    // A note whose every field is blank is not worth a heading.
    return latest.isEmpty ? null : latest;
  }

  List<T> _listFrom<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) parse,
  ) {
    return _rowsFrom(response).map(parse).toList(growable: false);
  }

  /// An error on one section is treated as "nothing here" rather than
  /// failing the whole record: a patient who can see their diagnosis and
  /// prescription is better served than one shown a full-screen error
  /// because the investigations call 403'd.
  List<Map<String, dynamic>> _rowsFrom(Response<dynamic> response) {
    if (response.statusCode != 200 || response.data is! Map) return const [];
    final results = (response.data as Map)['results'];
    if (results is! List) return const [];
    return results.cast<Map<String, dynamic>>();
  }
}
