import 'package:equatable/equatable.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the dashboard. Identity is passed in rather than read from AuthBloc
/// inside this Bloc, so HomeBloc has exactly one dependency direction and
/// stays trivially testable.
final class HomeStarted extends HomeEvent {
  const HomeStarted({
    required this.patientId,
    this.patientName,
    this.patientUsername,
  });

  final String patientId;
  final String? patientName;

  /// The backend's only real identifier. Used solely as a fallback for the
  /// avatar's initials when there is no real name — see
  /// [HomeState.avatarLabel].
  final String? patientUsername;

  @override
  List<Object?> get props => [patientId, patientName, patientUsername];
}

final class HomeRefreshed extends HomeEvent {
  const HomeRefreshed();
}

/// A notification arrived. Only the bell's count is refetched — reloading
/// the whole dashboard (location, clinicians) for one badge is wasteful.
final class HomeUnreadChanged extends HomeEvent {
  const HomeUnreadChanged();
}
