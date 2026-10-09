import 'package:equatable/equatable.dart';

import '../../domain/consultation.dart';

sealed class RecordsEvent extends Equatable {
  const RecordsEvent();

  @override
  List<Object?> get props => [];
}

final class RecordsStarted extends RecordsEvent {
  const RecordsStarted();
}

final class RecordsRefreshed extends RecordsEvent {
  const RecordsRefreshed();
}

/// Loads one consultation's artefacts. Fired when the patient opens a
/// record, never for the list — see [MedicalRecord] for why.
final class RecordOpened extends RecordsEvent {
  const RecordOpened(this.consultation);

  final Consultation consultation;

  @override
  List<Object?> get props => [consultation];
}
