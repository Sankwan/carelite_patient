import 'dart:async';

import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/auth/data/auth_repository.dart';
import 'package:carelite_app/features/auth/domain/auth_user.dart';
import 'package:carelite_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:carelite_app/features/auth/presentation/pages/email_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository authRepository;

  setUp(() {
    authRepository = _MockAuthRepository();
    when(() => authRepository.authStateChanges())
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildSubject() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>(
        create: (_) => AuthBloc(authRepository: authRepository),
        child: const EmailLoginPage(),
      ),
    );
  }

  /// Regression test: the field is labelled "Email", but the backend
  /// authenticates on `username` (verified live — see
  /// docs/PROJECT_STATUS.md), and demo/seeded accounts (`kofi`,
  /// `dr_adjei`, …) have usernames that are not email-shaped. An earlier
  /// version of this validator required "@" and "." and silently rejected
  /// every one of them before a request was ever sent.
  testWidgets('accepts a plain username, not only an email-shaped value',
      (tester) async {
    // Never completes during the test — this test is only about whether
    // validation *let the submit through*, not what happens after. Letting
    // the sign-in actually resolve would trigger AppToast, whose auto-close
    // Timer outlives a single pump() and trips flutter_test's
    // pending-timer check at teardown.
    when(() => authRepository.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) => Completer<Result<AuthUser>>().future);

    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byType(TextFormField).first, 'kofi');
    await tester.enterText(find.byType(TextFormField).last, 'carelite123');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    // No validation error was raised for "kofi" — if the old @-requiring
    // check were still in place, this text would be on screen instead.
    expect(find.text('Enter a valid email address'), findsNothing);
    verify(() => authRepository.signInWithPassword(
          email: 'kofi',
          password: 'carelite123',
        )).called(1);
  });

  testWidgets('still blocks a genuinely empty credential', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byType(TextFormField).last, 'carelite123');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    verifyNever(() => authRepository.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  });
}
