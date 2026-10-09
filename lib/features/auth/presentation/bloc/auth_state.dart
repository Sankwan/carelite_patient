import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/auth_user.dart';

enum AuthStatus { unknown, otpSent, authenticating, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.failure,
  });

  final AuthStatus status;
  final AuthUser? user;
  final Failure? failure;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, user, failure];
}
