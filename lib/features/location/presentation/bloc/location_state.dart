import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../data/location_repository.dart';

enum LocationStatus { initial, requesting, resolved }

class LocationState extends Equatable {
  const LocationState({
    this.status = LocationStatus.initial,
    this.access,
    this.failure,
  });

  final LocationStatus status;
  final LocationAccess? access;
  final Failure? failure;

  /// True once the funnel may move on — whether the user granted access,
  /// declined it, or skipped. Only a permanent denial keeps them here, so
  /// they can be shown the settings route.
  bool get isResolved =>
      status == LocationStatus.resolved && access != LocationAccess.deniedForever;

  LocationState copyWith({
    LocationStatus? status,
    LocationAccess? access,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return LocationState(
      status: status ?? this.status,
      access: access ?? this.access,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, access, failure];
}
