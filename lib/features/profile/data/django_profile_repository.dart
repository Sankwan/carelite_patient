import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/patient_account.dart';
import '../domain/patient_profile.dart';
import 'profile_repository.dart';

/// Patient profile against the Django API.
///
/// Verified live: `PATCH /api/accounts/me/patient-profile/` was hit against a
/// running instance of github.com/campofo/carelite and round-tripped
/// date_of_birth/sex/blood_group for real (see docs/PROJECT_STATUS.md).
///
/// The full name goes to `first_name` / `last_name` on the user. The
/// emergency contact (name + phone) is not sent: PatientProfile has only
/// `emergency_flag`, a boolean meaning "needs faster attention", and no
/// field to hold a contact (PT-C2 in docs/BACKEND_REQUESTS_PATIENT.md).
class DjangoProfileRepository implements ProfileRepository {
  const DjangoProfileRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<void>> saveProfile({
    required String userId,
    required PatientProfile profile,
  }) async {
    try {
      final name = _splitName(profile.fullName);
      if (name != null) {
        final nameResponse = await _client.patch(
          ApiContract.currentUser,
          data: {'first_name': name.first, 'last_name': name.last},
        );
        if (nameResponse.statusCode != 200) {
          return Result.err(UnexpectedFailure(_messageFrom(nameResponse.data)));
        }
      }
      final response = await _client.patch(
        ApiContract.patientProfile,
        data: {
          if (profile.dateOfBirth != null)
            'date_of_birth': _isoDate(profile.dateOfBirth!),
          if (profile.gender != null) 'sex': _sexFor(profile.gender!),
          if (profile.bloodType != null) 'blood_group': profile.bloodType!.label,
        },
      );
      if (response.statusCode == 200) return const Result.ok(null);
      return Result.err(UnexpectedFailure(_messageFrom(response.data)));
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<PatientAccount>> fetchAccount() async {
    try {
      // In parallel: the account screen needs both, and two sequential round
      // trips is a visibly slower open on a mobile connection.
      final responses = await Future.wait([
        _client.get(ApiContract.currentUser),
        _client.get(ApiContract.patientProfile),
      ]);
      final userResponse = responses[0];
      final profileResponse = responses[1];

      if (userResponse.statusCode == 401) {
        return const Result.err(
          AuthFailure('Your session has expired. Please sign in again.'),
        );
      }
      if (userResponse.statusCode != 200 || userResponse.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      try {
        return Result.ok(PatientAccount.fromDjangoJson(
          user: (userResponse.data as Map).cast<String, dynamic>(),
          // A clinician (or a patient whose profile row is somehow absent)
          // has no patient-profile; the account still renders, just without
          // the clinical fields. Failing the whole screen for it would lock
          // the user out of sign-out.
          profile: profileResponse.statusCode == 200 &&
                  profileResponse.data is Map
              ? (profileResponse.data as Map).cast<String, dynamic>()
              : null,
        ));
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read your profile (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  /// Date only, no timezone — a birthday must never shift a day.
  /// "Ama Serwaa Boateng" → first "Ama", last "Serwaa Boateng". The user
  /// model has the two fields; how a patient splits their own name is
  /// theirs to decide, so the first word is the only assumption made.
  ({String first, String last})? _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return null;
    return (first: parts.first, last: parts.skip(1).join(' '));
  }

  String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

  /// Backend choices are MALE/FEMALE/OTHER/UNKNOWN (accounts.models.
  /// PatientProfile.Sex); the app's chips are Female/Male/"Prefer not to
  /// say", so preferNotToSay maps to UNKNOWN — the nearest honest match.
  /// There is no app-side "Other" chip today, a minor known gap.
  String _sexFor(Gender gender) => switch (gender) {
        Gender.female => 'FEMALE',
        Gender.male => 'MALE',
        Gender.preferNotToSay => 'UNKNOWN',
      };

  String _messageFrom(dynamic body) {
    if (body is Map) {
      for (final value in body.values) {
        if (value is List && value.isNotEmpty) return '${value.first}';
      }
    }
    return 'Could not save your profile. Please try again.';
  }
}
