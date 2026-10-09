import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/consultation.dart';
import '../../domain/medical_record.dart';

enum RecordsStatus { loading, ready }

class RecordsState extends Equatable {
  const RecordsState({
    this.status = RecordsStatus.loading,
    this.consultations = const [],
    this.failure,
  });

  final RecordsStatus status;
  final List<Consultation> consultations;
  final Failure? failure;

  RecordsState copyWith({
    RecordsStatus? status,
    List<Consultation>? consultations,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RecordsState(
      status: status ?? this.status,
      consultations: consultations ?? this.consultations,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, consultations, failure];
}

enum RecordDetailStatus { loading, ready }

class RecordDetailState extends Equatable {
  const RecordDetailState({
    required this.consultation,
    this.status = RecordDetailStatus.loading,
    this.record,
    this.failure,
  });

  final Consultation consultation;
  final RecordDetailStatus status;
  final MedicalRecord? record;
  final Failure? failure;

  RecordDetailState copyWith({
    RecordDetailStatus? status,
    MedicalRecord? record,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RecordDetailState(
      consultation: consultation,
      status: status ?? this.status,
      record: record ?? this.record,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [consultation, status, record, failure];
}
