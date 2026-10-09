import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once at app start to attach the Supabase auth-state stream.
final class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

final class AuthOtpRequested extends AuthEvent {
  const AuthOtpRequested(this.phoneNumber);

  final String phoneNumber;

  @override
  List<Object?> get props => [phoneNumber];
}

final class AuthOtpVerified extends AuthEvent {
  const AuthOtpVerified({required this.phoneNumber, required this.otp});

  final String phoneNumber;
  final String otp;

  @override
  List<Object?> get props => [phoneNumber, otp];
}

final class AuthEmailSignInRequested extends AuthEvent {
  const AuthEmailSignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegistrationRequested extends AuthEvent {
  const AuthRegistrationRequested({
    required this.email,
    required this.password,
    required this.phone,
  });

  final String email;
  final String password;
  final String phone;

  @override
  List<Object?> get props => [email, password, phone];
}

/// Raised after Complete Profile saves successfully, so the router's
/// profile gate opens immediately instead of waiting for the next auth
/// stream emission (Supabase does not push on a `profiles` row change).
final class AuthProfileCompleted extends AuthEvent {
  const AuthProfileCompleted({this.fullName});

  /// Carried through so the name is available immediately — Home greets the
  /// patient by it. Without this the dashboard shows "Good afternoon" with
  /// no name and a "?" avatar until the next auth-stream emission, because
  /// Supabase does not push on a `profiles` row change.
  final String? fullName;

  @override
  List<Object?> get props => [fullName];
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
