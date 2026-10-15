import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/vitals_record.dart';

enum VitalsStatus { loading, ready }

final class VitalsState extends Equatable {
  const VitalsState({
    this.status = VitalsStatus.loading,
    this.records = const [],
    this.failure,
  });

  final VitalsStatus status;
  final List<VitalsRecord> records;
  final Failure? failure;

  /// Newest first, for display — the server returns oldest first so a
  /// trend read start-to-end makes chronological sense server-side.
  List<VitalsRecord> get newestFirst => records.reversed.toList(growable: false);

  VitalsState copyWith({
    VitalsStatus? status,
    List<VitalsRecord>? records,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return VitalsState(
      status: status ?? this.status,
      records: records ?? this.records,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, records, failure];
}
