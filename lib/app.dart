import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bootstrap.dart';
import 'core/constants/app_colors.dart';
import 'core/router/app_router.dart';
import 'core/storage/app_preferences.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Root widget. `AuthBloc` is provided once, above the router, because the
/// router's `redirect` and every screen below it need to read the same
/// instance of the current auth state (see [buildAppRouter]).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => getIt<AuthBloc>(),
      child: Builder(
        builder: (context) {
          final router = buildAppRouter(
            context.read<AuthBloc>(),
            getIt<AppPreferences>(),
          );
          return MaterialApp.router(
            title: 'Carelite',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.teal,
                primary: AppColors.teal,
                secondary: AppColors.blue,
                error: AppColors.error,
              ),
              fontFamily: 'Inter',
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
