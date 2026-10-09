import 'package:equatable/equatable.dart';

/// The subset of a Supabase auth user + profile row the rest of the app
/// actually needs. Kept separate from any backend's user payload so
/// UI/Bloc code never depends on the Supabase SDK directly.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.phone,
    this.username = '',
    this.fullName,
    this.role = AppRole.patient,
    this.hasCompletedProfile = false,
  });

  final String id;
  final String phone;

  /// The backend's only real identifier — `GET /api/accounts/me/`'s
  /// `username`. For a patient who registered through this app it happens
  /// to be their email (see `DjangoAuthRepository.registerWithEmail`), but
  /// for the seeded demo patients (`kofi`, `ama`, …) it's a plain name.
  /// Kept raw here — formatting it into something display-worthy (and never
  /// showing a raw email as a name) is a UI decision, not this layer's.
  final String username;

  final String? fullName;
  final AppRole role;
  final bool hasCompletedProfile;

  AuthUser copyWith({
    String? id,
    String? phone,
    String? username,
    String? fullName,
    AppRole? role,
    bool? hasCompletedProfile,
  }) {
    return AuthUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      hasCompletedProfile: hasCompletedProfile ?? this.hasCompletedProfile,
    );
  }

  @override
  List<Object?> get props =>
      [id, phone, username, fullName, role, hasCompletedProfile];
}

/// Mapped from the backend's `role` (`PATIENT`, `CLINICIAN`, `FACILITY`,
/// `ADMIN`). Only [patient] may sign in to this app.
enum AppRole { patient, providerClinician, providerLab, providerPharmacy, admin }
