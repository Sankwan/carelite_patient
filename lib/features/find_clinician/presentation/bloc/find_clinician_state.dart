import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../../home/domain/provider.dart';
import '../../domain/search_filter.dart';

enum FindClinicianStatus { loading, ready }

class FindClinicianState extends Equatable {
  const FindClinicianState({
    this.status = FindClinicianStatus.loading,
    this.clinicians = const [],
    this.filter = const ClinicianFilter(),
    this.failure,
  });

  final FindClinicianStatus status;
  final List<Provider> clinicians;
  final ClinicianFilter filter;
  final Failure? failure;

  /// An empty result with a filter applied is a normal outcome ("nobody
  /// practices that here"), not an error — the two need different screens,
  /// so the page asks this rather than inferring from `clinicians.isEmpty`.
  bool get isEmptyBecauseOfFilters =>
      clinicians.isEmpty && failure == null && filter.isActive;

  bool get isEmptyEntirely =>
      clinicians.isEmpty && failure == null && !filter.isActive;

  FindClinicianState copyWith({
    FindClinicianStatus? status,
    List<Provider>? clinicians,
    ClinicianFilter? filter,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return FindClinicianState(
      status: status ?? this.status,
      clinicians: clinicians ?? this.clinicians,
      filter: filter ?? this.filter,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, clinicians, filter, failure];
}
