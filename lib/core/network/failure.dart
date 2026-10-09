/// A small, explicit error hierarchy instead of throwing raw exceptions
/// across layers. Repositories return `Result<T>` (see result.dart-style
/// usage in auth_repository.dart) so the UI layer always knows how to
/// react without inspecting exception types.
sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Could not reach the server. Check your connection.']);
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong. Please try again.']);
}

/// A capability the backend has not shipped yet.
///
/// Deliberately its own type rather than a generic error: the UI must be
/// able to tell "this is broken" apart from "this does not exist yet" and
/// say so honestly. Never construct this to paper over a call that failed —
/// it means the endpoint does not exist, not that it errored.
final class NotImplementedFailure extends Failure {
  const NotImplementedFailure([
    super.message = 'This is not available yet.',
  ]);
}
