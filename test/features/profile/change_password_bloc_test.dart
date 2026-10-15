import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/auth/data/auth_repository.dart';
import 'package:carelite_app/features/profile/presentation/bloc/change_password_bloc.dart';
import 'package:carelite_app/features/profile/presentation/bloc/change_password_event.dart';
import 'package:carelite_app/features/profile/presentation/bloc/change_password_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() => repository = _MockAuthRepository());

  ChangePasswordBloc build() => ChangePasswordBloc(authRepository: repository);

  blocTest<ChangePasswordBloc, ChangePasswordState>(
    'a successful change ends on done',
    build: () {
      when(() => repository.changePassword(
            oldPassword: 'old123',
            newPassword: 'newpass456',
          )).thenAnswer((_) async => const Result.ok(null));
      return build();
    },
    act: (bloc) => bloc.add(const ChangePasswordSubmitted(
      oldPassword: 'old123',
      newPassword: 'newpass456',
    )),
    expect: () => [
      const ChangePasswordState(status: ChangePasswordStatus.submitting),
      const ChangePasswordState(status: ChangePasswordStatus.done),
    ],
  );

  blocTest<ChangePasswordBloc, ChangePasswordState>(
    'a refused change goes back to idle with the server\'s reason',
    build: () {
      when(() => repository.changePassword(
            oldPassword: 'wrong',
            newPassword: 'newpass456',
          )).thenAnswer(
        (_) async =>
            const Result.err(AuthFailure('Current password is incorrect.')),
      );
      return build();
    },
    act: (bloc) => bloc.add(const ChangePasswordSubmitted(
      oldPassword: 'wrong',
      newPassword: 'newpass456',
    )),
    verify: (bloc) {
      expect(bloc.state.status, ChangePasswordStatus.idle);
      expect(bloc.state.failure?.message, 'Current password is incorrect.');
    },
  );
}
