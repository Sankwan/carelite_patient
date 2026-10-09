
import '../../../core/utils/result.dart';
import '../domain/patient_account.dart';
import '../domain/patient_profile.dart';

/// Abstract so the Bloc depends on this contract, not on Supabase — same
/// seam as [AuthRepository], and what lets the Bloc test run without a
/// network client.
abstract class ProfileRepository {
  Future<Result<void>> saveProfile({
    required String userId,
    required PatientProfile profile,
  });

  /// The signed-in patient's account and clinical profile, read together.
  ///
  /// Both rows are needed for one screen and neither is derivable from the
  /// other, so this fetches both rather than making the Bloc orchestrate
  /// two calls.
  Future<Result<PatientAccount>> fetchAccount();
}
