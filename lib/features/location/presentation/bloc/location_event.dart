import 'package:equatable/equatable.dart';

sealed class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

/// "Allow Location Access" — triggers the real OS prompt.
final class LocationPermissionRequested extends LocationEvent {
  const LocationPermissionRequested();
}

/// "Maybe Later" — records that we asked, so the funnel never re-prompts,
/// and lets the user through. Browsing without location is supported.
final class LocationSkipped extends LocationEvent {
  const LocationSkipped();
}

final class LocationSettingsOpened extends LocationEvent {
  const LocationSettingsOpened();
}
