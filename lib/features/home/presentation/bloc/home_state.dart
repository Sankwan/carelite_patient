import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../../../core/utils/display_name.dart';
import '../../domain/appointment.dart';
import '../../domain/provider.dart';

enum HomeStatus { loading, ready, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.loading,
    this.patientId = '',
    this.patientName,
    this.patientUsername,
    this.upcoming,
    this.nearbyClinicians = const [],
    this.recentActivity = const [],
    this.hasLocation = false,
    this.locationLabel,
    this.unreadNotifications = 0,
    this.failure,
  });

  final HomeStatus status;
  final String patientId;
  final String? patientName;

  /// The backend's only real identifier — used solely as a fallback for the
  /// avatar's initials when there is no [patientName] (which is always the
  /// case on this backend today; see [avatarLabel]).
  final String? patientUsername;

  final Appointment? upcoming;
  final List<Provider> nearbyClinicians;
  final List<Appointment> recentActivity;

  /// False when the patient declined location: providers still render, just
  /// without distance labels.
  final bool hasLocation;

  /// "Tamale, Northern Region" — a real place name reverse-geocoded from the
  /// device's coordinates, shown under the patient's name on Home. Null
  /// whenever [hasLocation] is false, and also (a normal outcome, not an
  /// error) when the on-device geocoder can't resolve a name for a real
  /// position — the header falls back to a generic label rather than
  /// showing nothing.
  final String? locationLabel;

  /// Drives the header bell's badge, from
  /// `GET /api/notifications/unread-count/`. Zero is also the value used
  /// when that call fails — a stale-looking badge is worse than none, and
  /// the count is never load-bearing for anything but the dot.
  final int unreadNotifications;
  final Failure? failure;

  /// True for a patient with no care history yet. Derived rather than
  /// stored, so it can never disagree with what is on screen: it is exactly
  /// the condition under which neither the upcoming hero nor Recent Activity
  /// renders (requirement #6).
  bool get isNewUser => upcoming == null && recentActivity.isEmpty;

  /// "Good morning" / "Good afternoon" / "Good evening", from the device
  /// clock — the Figma greeting is a fixed string.
  String greeting({DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// First name only, matching "Good morning, Esi" in the design.
  String? get firstName {
    final name = patientName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  /// What the header's avatar shows its initials from. Prefers a real name
  /// (never happens today — this backend has none), and falls back to the
  /// formatted username rather than '?' for every signed-in patient, which
  /// is what shipped before this existed: the avatar read as broken for
  /// every account, not just ones with no name on file. Deliberately not
  /// used for the greeting text itself — "Good afternoon, kofi@example.gh"
  /// for a patient who registered by email is not an improvement; a two-
  /// letter monogram reads fine regardless of what the username looks like.
  String? get avatarLabel {
    final name = firstName;
    if (name != null) return name;
    final username = patientUsername?.trim();
    if (username == null || username.isEmpty) return null;
    return formatUsername(username);
  }

  HomeState copyWith({
    HomeStatus? status,
    String? patientId,
    String? patientName,
    String? patientUsername,
    Appointment? upcoming,
    bool clearUpcoming = false,
    List<Provider>? nearbyClinicians,
    List<Appointment>? recentActivity,
    bool? hasLocation,
    String? locationLabel,
    bool clearLocationLabel = false,
    int? unreadNotifications,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientUsername: patientUsername ?? this.patientUsername,
      upcoming: clearUpcoming ? null : (upcoming ?? this.upcoming),
      nearbyClinicians: nearbyClinicians ?? this.nearbyClinicians,
      recentActivity: recentActivity ?? this.recentActivity,
      hasLocation: hasLocation ?? this.hasLocation,
      locationLabel:
          clearLocationLabel ? null : (locationLabel ?? this.locationLabel),
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        status, patientId, patientName, patientUsername, upcoming,
        nearbyClinicians, recentActivity, hasLocation, locationLabel,
        unreadNotifications, failure,
      ];
}
