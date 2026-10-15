import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bootstrap.dart';
import 'core/constants/app_colors.dart';
import 'core/realtime/realtime_client.dart';
import 'core/realtime/realtime_session.dart';
import 'core/router/app_router.dart';
import 'core/storage/app_preferences.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/messages/domain/open_conversation.dart';
import 'features/messages/presentation/bloc/messages_badge_bloc.dart';
import 'features/messages/presentation/bloc/messages_badge_event.dart';
import 'features/notifications/presentation/widgets/live_notification_toasts.dart';

/// Root widget. `AuthBloc` is provided once, above the router, because the
/// router's `redirect` and every screen below it need to read the same
/// instance of the current auth state (see [buildAppRouter]).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => getIt<AuthBloc>()),
        BlocProvider<MessagesBadgeBloc>.value(
            value: getIt<MessagesBadgeBloc>()),
      ],
      // The live connection follows the session: open while signed in,
      // closed on sign-out so no events reach a signed-out device.
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          final signedIn = state.status == AuthStatus.authenticated;
          getIt<RealtimeSession>().signedInChanged(signedIn: signedIn);
          if (signedIn) {
            context
                .read<MessagesBadgeBloc>()
                .add(const MessagesBadgeRefreshed());
          }
        },
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
              builder: (context, child) => LiveNotificationToasts(
                events: getIt<RealtimeClient>().events,
                navigatorKey: router.routerDelegate.navigatorKey,
                shouldShow: (notification) =>
                    notification.payload['conversation_id']?.toString() !=
                    getIt<OpenConversation>().id,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
