import '../../../core/utils/result.dart';
import '../domain/auth_user.dart';

/// The contract every auth backend implements.
///
/// Abstract so the Bloc depends on this, not on a specific backend — which
/// is what let the Supabase→Django swap happen without touching a single
/// Bloc or widget. Fake it with mocktail in tests.
///
/// Implemented by `DjangoAuthRepository`. The former SupabaseAuthRepository
/// was deleted rather than kept alongside: two registered implementations
/// would mean two identity systems issuing tokens for the same user.
abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  /// Signup collects email, password and phone together — the confirmed
  /// product design, even though the phone is not yet usable for login.
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String phone,
  });

  Future<Result<AuthUser>> signInWithPassword({
    required String email,
    required String password,
  });

  /// Fallback path for a patient with no email on file. Kept deliberately:
  /// phone+OTP is confirmed product direction and the Ghana market runs on
  /// it — the Django backend simply has not shipped the endpoints yet, so
  /// implementations return NotImplementedFailure rather than pretending.
  Future<Result<void>> sendOtp(String phoneNumber);

  Future<Result<AuthUser>> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  Future<void> signOut();
}
