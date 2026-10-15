import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/display_name.dart';
import '../../../core/utils/initials.dart';

import 'patient_profile.dart';

/// The patient's account as the backend actually stores it: the `User` row
/// (`GET /api/accounts/me/`) plus the `PatientProfile` row
/// (`GET /api/accounts/me/patient-profile/`), read together.
///
/// There is deliberately no `fullName` here. This backend has no name field
/// anywhere — not `first_name`/`last_name` on User (they exist on the Django
/// model but are not exposed by `UserSerializer`), not on PatientProfile.
/// `username` is the only human-readable identifier, and for patients who
/// registered through this app it is their email address. Inventing a
/// display name would mean showing something the record does not contain.
class PatientAccount extends Equatable {
  const PatientAccount({
    required this.id,
    required this.username,
    this.fullName,
    this.email = '',
    this.phone = '',
    this.dateOfBirth,
    this.sex,
    this.bloodGroup,
    this.allergies = '',
    this.emergencyFlag = false,
  });

  factory PatientAccount.fromDjangoJson({
    required Map<String, dynamic> user,
    Map<String, dynamic>? profile,
  }) {
    return PatientAccount(
      id: '${user['id']}',
      username: user['username'] as String? ?? '',
      fullName: realNameOrNull(user['full_name']),
      email: user['email'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
      dateOfBirth: DateTime.tryParse(
        profile?['date_of_birth'] as String? ?? '',
      ),
      sex: _genderFrom(profile?['sex'] as String?),
      bloodGroup: profile?['blood_group'] as String?,
      allergies: profile?['allergies'] as String? ?? '',
      emergencyFlag: profile?['emergency_flag'] as bool? ?? false,
    );
  }

  final String id;
  final String username;

  /// Null when the account has no name set.
  final String? fullName;

  /// What to call the patient on screen: their name, else their username.
  String get displayName => fullName ?? username;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final Gender? sex;

  /// A free-text string server-side ("O+"), not an enum — so it is shown
  /// as-is rather than parsed into [BloodType] and risking a blank when the
  /// backend holds something the app's eight chips do not cover.
  final String? bloodGroup;

  final String allergies;

  /// `PatientProfile.emergency_flag` — "this patient needs faster
  /// attention". It is NOT an emergency contact; the backend has no name or
  /// phone to call, which is why Complete Profile's contact fields have
  /// nowhere to save to.
  final bool emergencyFlag;

  /// Date only, no timezone: a birthday must never shift a day.
  String? get dateOfBirthLabel {
    final date = dateOfBirth;
    if (date == null) return null;
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Whole years, computed from the clock — never stored, so it cannot go
  /// stale.
  int? get age {
    final date = dateOfBirth;
    if (date == null) return null;
    final now = DateTime.now();
    var years = now.year - date.year;
    final hadBirthday = now.month > date.month ||
        (now.month == date.month && now.day >= date.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? null : years;
  }

  /// The initial for the avatar. Falls back to '?' rather than crashing on
  /// an empty username.
  String get initials {
    final name = fullName;
    if (name != null) return initialsOf(name);
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static Gender? _genderFrom(String? value) => switch (value) {
        'MALE' => Gender.male,
        'FEMALE' => Gender.female,
        'OTHER' || 'UNKNOWN' => Gender.preferNotToSay,
        _ => null,
      };

  @override
  List<Object?> get props => [
        id, username, fullName, email, phone, dateOfBirth, sex,
        bloodGroup, allergies, emergencyFlag,
      ];
}
