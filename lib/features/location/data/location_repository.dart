import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';

/// What the OS told us after the permission prompt. Kept as our own enum
/// rather than leaking geolocator's [LocationPermission] into the Bloc, so
/// the plugin stays swappable and the Bloc test needs no platform channel.
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// A coordinate pair, kept plain so nothing outside this file depends on
/// geolocator's Position type.
typedef Coordinates = ({double latitude, double longitude});

abstract class LocationRepository {
  Future<Result<LocationAccess>> requestPermission();

  /// The device's current position, or null when the patient has not granted
  /// access. Null is an ordinary outcome, not an error: browsing without
  /// location is supported, it just costs the distance labels.
  Future<Result<Coordinates?>> currentPosition();

  /// Opens the OS settings page — the only recovery path once a user has
  /// permanently denied access.
  Future<void> openSettings();

  /// A human-readable place name for [coordinates] — "Tamale, Northern
  /// Region", roughly locality + administrative area — or null if the
  /// device's geocoder can't resolve it (no network, no Play Services on
  /// some Android emulators, or genuinely nothing there). Null is a normal
  /// outcome: the caller falls back to a generic label, never blank, never
  /// a crash.
  Future<Result<String?>> placeNameFor(Coordinates coordinates);
}

class GeolocatorLocationRepository implements LocationRepository {
  const GeolocatorLocationRepository();

  @override
  Future<Result<LocationAccess>> requestPermission() async {
    try {
      // Permission is meaningless if location services are switched off
      // device-wide, so check that first and report it distinctly.
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Result.ok(LocationAccess.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return Result.ok(switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine =>
          LocationAccess.denied,
      });
    } catch (_) {
      return const Result.err(
        UnexpectedFailure('Could not check location access on this device.'),
      );
    }
  }

  @override
  Future<Result<Coordinates?>> currentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return const Result.ok(null);

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            // A radius search does not need a precise fix, and waiting on
            // one would hold the whole dashboard behind the GPS.
            timeLimit: Duration(seconds: 8),
          ),
        );
        return Result.ok((latitude: position.latitude, longitude: position.longitude));
      } catch (_) {
        // A fresh fix can time out even when the device already has a
        // recent one cached (slow GPS lock, a device that just woke up, or
        // — verified live — some Android emulators, where a single-shot
        // HIGH_ACCURACY request can take far longer than 8s to resolve even
        // though `dumpsys location` already shows a valid last-known fix).
        // Falling back to that cached position is still a real location,
        // just possibly a little stale — worth using rather than treating
        // the whole dashboard as location-less.
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null) return const Result.ok(null);
        return Result.ok((latitude: lastKnown.latitude, longitude: lastKnown.longitude));
      }
    } catch (_) {
      // A timeout or an unavailable sensor degrades to "no location" rather
      // than failing the screen that depends on it.
      return const Result.ok(null);
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  Future<Result<String?>> placeNameFor(Coordinates coordinates) async {
    try {
      // geocoding ^5.0.0's API is instance-based, not top-level functions —
      // a plain constructor call, no state worth caching across requests.
      final placemarks = await geocoding.Geocoding().placemarkFromCoordinates(
            coordinates.latitude,
            coordinates.longitude,
          );
      if (placemarks.isEmpty) return const Result.ok(null);
      return Result.ok(_labelFrom(placemarks.first));
    } catch (_) {
      // No network, no Play Services on some Android emulators, or a
      // genuinely unresolvable point — degrades to "no label" rather than
      // failing the screen that shows it.
      return const Result.ok(null);
    }
  }

  /// "Tamale, Northern Region" — locality + the broader administrative area,
  /// which is the granularity a patient actually reads at a glance. Falls
  /// back one field at a time rather than an all-or-nothing template, since
  /// Ghanaian geocoder results don't always populate every field the same
  /// way a US/UK one would.
  String? _labelFrom(geocoding.Placemark placemark) {
    final locality = _clean(placemark.locality) ?? _clean(placemark.subAdministrativeArea);
    final region = _clean(placemark.administrativeArea);
    if (locality != null && region != null && locality != region) {
      return '$locality, $region';
    }
    return locality ?? region ?? _clean(placemark.country);
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
