import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/api/drf_error.dart';
import '../../../core/network/api/token_store.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/display_name.dart';
import '../../../core/utils/result.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

/// Auth against the team's Django + simplejwt API.
///
/// Two paths, deliberately unequal in maturity:
///   * email + password — live on both ends, verified against a running
///     instance of github.com/campofo/carelite (register → login → /me →
///     patient-profile all hit for real; see docs/PROJECT_STATUS.md).
///   * phone + OTP — confirmed product direction, but no OTP endpoints exist
///     anywhere in that backend's urls.py. Returns [NotImplementedFailure]
///     and never fabricates a session.
///
/// Session state is a stream because [AuthBloc] and the router's redirect
/// were built around one, and because a dead refresh token can end a session
/// at any moment — the client pushes that through [ApiClient.onSessionExpired]
/// rather than leaving the app on a screen it can no longer load.
class DjangoAuthRepository implements AuthRepository {
  DjangoAuthRepository({required ApiClient client, required TokenStore tokenStore})
      : _client = client,
        _tokenStore = tokenStore {
    _expirySubscription = _client.onSessionExpired.listen((_) {
      _controller.add(null);
    });
  }

  final ApiClient _client;
  final TokenStore _tokenStore;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  late final StreamSubscription<void> _expirySubscription;

  AuthUser? _current;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    // Replay the restored session first so a cold start does not flash the
    // login screen at someone who is already signed in.
    yield await _restoreSession();
    yield* _controller.stream;
  }

  Future<AuthUser?> _restoreSession() async {
    if (!await _tokenStore.hasSession) return null;
    final result = await _fetchCurrentUser();
    final user = result.when(ok: (user) => user, err: (_) => null);
    // A cached non-patient session is dropped on restore for the same reason
    // one is refused at sign-in — see [_rejectNonPatient].
    _current = user != null && user.role == AppRole.patient ? user : null;
    if (_current == null) await _tokenStore.clear();
    return _current;
  }

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String phone,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _client.post(
        ApiContract.register,
        data: {
          // RegisterSerializer requires `username` (AbstractUser.username is
          // required + unique) and there is no separate email-only signup —
          // username==email is what lets the login screen collect only an
          // email, per the confirmed design, and still hit a real field.
          'username': normalizedEmail,
          'email': normalizedEmail,
          'password': password,
          'phone': phone.trim(),
          'role': 'PATIENT',
        },
        options: ApiClient.unauthenticated,
      );

      if (response.statusCode == 404) {
        return const Result.err(NotImplementedFailure(
          'Account signup is not available yet. Please try again later.',
        ));
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        return Result.err(AuthFailure(_messageFrom(response.data)));
      }

      // Verified shape: POST /api/accounts/register/ returns
      // {user, role, access, refresh} — tokens are top-level, not nested.
      final body = response.data;
      if (body is Map && body[ApiContract.accessTokenKey] != null) {
        await _persistTokens(body);
        return _loadAndPublishUser();
      }
      return signInWithPassword(email: email, password: password);
    } on DioException catch (e) {
      return Result.err(_networkFailure(e));
    }
  }

  @override
  Future<Result<AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        ApiContract.tokenObtain,
        data: {
          // Verified: this is `username` on the wire (see ApiContract
          // .credentialField), not `email` — the backend has no email login.
          // The value passed here is still whatever the patient typed in the
          // email field; it round-trips correctly because registration set
          // username == email.
          ApiContract.credentialField: email.trim(),
          'password': password,
        },
        options: ApiClient.unauthenticated,
      );

      if (response.statusCode == 401) {
        return const Result.err(
          AuthFailure('Incorrect email or password.'),
        );
      }
      if (response.statusCode != 200) {
        return Result.err(AuthFailure(_messageFrom(response.data)));
      }

      // Verified shape: {access, refresh, role, user_id, username} — no
      // nested "user" object, unlike register. Identity still comes from a
      // follow-up /me call so both paths converge on one mapping function.
      final body = response.data;
      if (body is! Map || body[ApiContract.accessTokenKey] == null) {
        return const Result.err(
          UnexpectedFailure('Sign-in response was not in the expected format.'),
        );
      }

      await _persistTokens(body);
      return _loadAndPublishUser();
    } on DioException catch (e) {
      return Result.err(_networkFailure(e));
    }
  }

  // No OTP endpoints exist anywhere in this backend's urls.py — confirmed by
  // reading every app's url conf, not just accounts/. Returning
  // NotImplementedFailure is load-bearing: a stub that returned Result.ok
  // would sign a patient in with no session behind it.
  @override
  Future<Result<void>> sendOtp(String phoneNumber) async {
    return const Result.err(NotImplementedFailure(
      'Phone sign-in is coming soon. Please use your email and password.',
    ));
  }

  @override
  Future<Result<AuthUser>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    return const Result.err(NotImplementedFailure(
      'Phone sign-in is coming soon. Please use your email and password.',
    ));
  }

  @override
  Future<void> signOut() async {
    // Revoke the refresh token so a copy of it is useless after sign-out.
    // Best-effort: being offline must never keep someone signed in, so the
    // local pair is cleared whatever the server says.
    final refresh = await _tokenStore.readRefresh();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _client
            .post(ApiContract.logout, data: {ApiContract.refreshTokenKey: refresh})
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await _tokenStore.clear();
    _current = null;
    _controller.add(null);
  }

  Future<void> dispose() async {
    await _expirySubscription.cancel();
    await _controller.close();
  }

  Future<void> _persistTokens(Map<dynamic, dynamic> body) {
    return _tokenStore.save(
      access: body[ApiContract.accessTokenKey] as String,
      refresh: (body[ApiContract.refreshTokenKey] as String?) ?? '',
    );
  }

  Future<Result<AuthUser>> _loadAndPublishUser() async {
    final result = await _fetchCurrentUser();
    return result.when(
      ok: (user) async {
        final rejection = await _rejectNonPatient(user);
        if (rejection != null) return rejection;
        _current = user;
        _controller.add(user);
        return Result.ok(user);
      },
      err: (failure) async => Result<AuthUser>.err(failure),
    );
  }

  /// CareLite is a patient app. A clinician, facility or admin account can
  /// authenticate perfectly well against this shared backend, but every
  /// screen here is patient-scoped: booking is `IsPatient`-only server-side,
  /// records read the patient's own consultations, and the profile screen
  /// reads `me/patient-profile/`, which a clinician does not have.
  ///
  /// Letting them in produced a dashboard that looked functional and then
  /// failed on every action — a clinician who tapped "Book appointment" got
  /// "This action is only available to patients." from the server, with no
  /// explanation of why the app had offered it. Refusing at the door, with
  /// the reason, is the honest version.
  ///
  /// The tokens are cleared too: a rejected sign-in must not leave a usable
  /// session behind it.
  Future<Result<AuthUser>?> _rejectNonPatient(AuthUser user) async {
    if (user.role == AppRole.patient) return null;
    await _tokenStore.clear();
    _current = null;
    _controller.add(null);
    return const Result.err(AuthFailure(
      'This account is not a patient account. CareLite is for patients — '
      'clinician and facility accounts use a different app.',
    ));
  }

  /// simplejwt returns only tokens, so identity comes from GET /me/ — verified
  /// against `accounts.serializers.UserSerializer`.
  Future<Result<AuthUser>> _fetchCurrentUser() async {
    try {
      final response = await _client.get(ApiContract.currentUser);
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(UnexpectedFailure(
          'Signed in, but your profile could not be loaded.',
        ));
      }
      final row = (response.data as Map).cast<String, dynamic>();
      final hasCompletedProfile = await _hasCompletedProfile(row);
      return Result.ok(_mapUser(row, hasCompletedProfile: hasCompletedProfile));
    } on DioException catch (e) {
      return Result.err(_networkFailure(e));
    }
  }

  /// The backend has no "profile completed" concept at all — confirmed:
  /// `UserSerializer` and `PatientProfileSerializer` both lack such a field.
  /// This app still needs one to gate the Complete Profile funnel screen, so
  /// it is derived: a patient counts as done once they have a date of birth
  /// on file. Non-patient roles skip the funnel outright —
  /// this app is the patient console; a clinician/facility/admin account has
  /// no patient-profile row to check.
  Future<bool> _hasCompletedProfile(Map<String, dynamic> userRow) async {
    if ((userRow['role'] as String?)?.toUpperCase() != 'PATIENT') return true;
    try {
      final response = await _client.get(ApiContract.patientProfile);
      if (response.statusCode != 200 || response.data is! Map) return false;
      final profile = response.data as Map;
      return profile['date_of_birth'] != null;
    } on DioException {
      // Best-effort: a failed check just re-shows Complete Profile, which is
      // safe (idempotent) rather than silently skipping it.
      return false;
    }
  }

  AuthUser _mapUser(
    Map<String, dynamic> row, {
    required bool hasCompletedProfile,
  }) {
    final role = (row['role'] as String?)?.toUpperCase();
    return AuthUser(
      id: '${row['id'] ?? ''}',
      phone: row['phone'] as String? ?? '',
      username: row['username'] as String? ?? '',
      // The real name when the account has one. Never the username: for
      // accounts registered through this app that is the patient's email.
      fullName: realNameOrNull(row['full_name']),
      role: switch (role) {
        'CLINICIAN' => AppRole.providerClinician,
        // The backend's FACILITY role does not distinguish lab / imaging /
        // pharmacy at the user level — that lives on Facility.type via the
        // `operator` link. providerLab is a best-effort default; this app
        // has no facility-operator console anyway.
        'FACILITY' => AppRole.providerLab,
        'ADMIN' => AppRole.admin,
        _ => AppRole.patient,
      },
      hasCompletedProfile: hasCompletedProfile,
    );
  }

  Failure _networkFailure(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    return const NetworkFailure();
  }

  /// Django REST Framework returns errors as {"field": ["msg"]} or
  /// {"detail": "msg"} — verified against both a bad-login 401 and a
  /// duplicate-registration 400 from the live server. Shared with the
  /// booking repository, which hits both shapes too.
  String _messageFrom(dynamic body) => drfMessage(body);
}
