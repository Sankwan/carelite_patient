import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bootstrap.dart';
import '../../features/appointments/presentation/bloc/appointments_bloc.dart';
import '../../features/appointments/presentation/bloc/appointments_event.dart';
import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/email_login_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_verify_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/find_clinician/domain/search_filter.dart';
import '../../features/find_clinician/presentation/bloc/find_clinician_bloc.dart';
import '../../features/find_clinician/presentation/bloc/find_clinician_event.dart';
import '../../features/find_clinician/presentation/pages/find_clinician_page.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/location/presentation/bloc/location_bloc.dart';
import '../../features/location/presentation/pages/enable_location_page.dart';
import '../../features/medical_records/presentation/bloc/records_bloc.dart';
import '../../features/medical_records/presentation/bloc/records_event.dart';
import '../../features/medical_records/presentation/pages/medical_records_page.dart';
import '../../features/messages/presentation/bloc/conversations_bloc.dart';
import '../../features/messages/presentation/bloc/conversations_event.dart';
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_event.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/onboarding/presentation/bloc/onboarding_bloc.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/profile/presentation/bloc/profile_event.dart';
import '../../features/profile/presentation/bloc/profile_setup_bloc.dart';
import '../../features/profile/presentation/pages/complete_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../storage/app_preferences.dart';
import 'app_shell.dart';

/// Route names, kept as constants so features don't hand-roll path strings.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String completeProfile = '/complete-profile';
  static const String enableLocation = '/enable-location';
  static const String home = '/home';

  // Shell tabs.
  static const String appointments = '/appointments';
  static const String messages = '/messages';
  static const String medicalRecords = '/records';
  static const String profileTab = '/profile';

  // Pushed over the shell.
  static const String findClinician = '/find-clinician';
  static const String findSpecialists = '/find-specialists';
  static const String notifications = '/notifications';
}

/// Bridges a Bloc's stream to a [Listenable] so `GoRouter` re-evaluates its
/// `redirect` whenever [AuthBloc] emits — without this, `GoRouter` only
/// re-runs `redirect` on navigation, so a background auth-state change
/// (e.g. token expiry, sign-out from another tab) would never redirect.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Builds the app's router.
///
/// `redirect` is the single gate for the whole signup funnel, evaluated in
/// a fixed order — onboarding (device-local, pre-auth) → authentication →
/// profile setup → location prompt → home. Keeping the order here, rather
/// than letting each screen push the next one, means a user who kills the
/// app mid-funnel resumes at exactly the right step on relaunch.
///
/// This app is patient-only: non-patient roles are refused at sign-in, and
/// clinicians use the separate clinician app.
GoRouter buildAppRouter(AuthBloc authBloc, AppPreferences preferences) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Splash decides when to leave on its own; never bounce it early.
      if (location == AppRoutes.splash) return null;

      if (!preferences.hasCompletedOnboarding) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      final authStatus = authBloc.state.status;
      // Still resolving the initial session — hold position rather than
      // flashing the login screen at an already-signed-in user.
      if (authStatus == AuthStatus.unknown) return null;

      final isAuthenticated = authStatus == AuthStatus.authenticated;
      final inAuthFlow = location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.otp;

      if (!isAuthenticated) return inAuthFlow ? null : AppRoutes.login;

      if (authBloc.state.user?.hasCompletedProfile == false) {
        return location == AppRoutes.completeProfile
            ? null
            : AppRoutes.completeProfile;
      }

      if (!preferences.hasSeenLocationPrompt) {
        return location == AppRoutes.enableLocation
            ? null
            : AppRoutes.enableLocation;
      }

      // Fully onboarded: the funnel screens are behind them now. Everything
      // else — the five tabs and anything pushed over them — is allowed.
      if (inAuthFlow ||
          location == AppRoutes.onboarding ||
          location == AppRoutes.completeProfile ||
          location == AppRoutes.enableLocation) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        // Each funnel screen owns its Bloc for exactly as long as it is on
        // screen — scoped here rather than app-wide so nothing leaks into
        // the authenticated part of the app.
        builder: (context, state) => BlocProvider<OnboardingBloc>(
          create: (_) => getIt<OnboardingBloc>(),
          child: const OnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        // Email + password is the live path; the OTP LoginPage is kept for
        // the phone fallback and is reachable once the backend ships it.
        builder: (context, state) => const EmailLoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        // The number is passed as `extra` rather than a path/query segment
        // so it never lands in browser history or a deep link. A direct hit
        // on /otp has nothing to verify, so it falls back to login.
        builder: (context, state) {
          final phoneNumber = state.extra as String?;
          if (phoneNumber == null) return const LoginPage();
          return OtpVerifyPage(phoneNumber: phoneNumber);
        },
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) => BlocProvider<ProfileSetupBloc>(
          create: (_) => getIt<ProfileSetupBloc>(),
          child: const CompleteProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.enableLocation,
        builder: (context, state) => BlocProvider<LocationBloc>(
          create: (_) => getIt<LocationBloc>(),
          child: const EnableLocationPage(),
        ),
      ),
      // The authenticated app lives inside one StatefulShellRoute so the five
      // tabs each keep their own navigator and scroll position.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) =>
                  HomePageLoader(createBloc: () => getIt<HomeBloc>()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.appointments,
              builder: (context, state) => BlocProvider<AppointmentsBloc>(
                create: (_) =>
                    getIt<AppointmentsBloc>()..add(const AppointmentsStarted()),
                child: const AppointmentsPage(),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.messages,
              builder: (context, state) => BlocProvider<ConversationsBloc>(
                create: (_) =>
                    getIt<ConversationsBloc>()..add(const ConversationsStarted()),
                child: const MessagesPage(),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.medicalRecords,
              builder: (context, state) => BlocProvider<RecordsBloc>(
                create: (_) => getIt<RecordsBloc>()..add(const RecordsStarted()),
                child: const MedicalRecordsPage(),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profileTab,
              builder: (context, state) => BlocProvider<ProfileBloc>(
                create: (_) => getIt<ProfileBloc>()..add(const ProfileStarted()),
                child: const ProfilePage(),
              ),
            ),
          ]),
        ],
      ),

      // Pushed on top of the shell, so the bottom nav is hidden while they
      // are open — both are entered from Home and returned from.
      GoRoute(
        path: AppRoutes.findClinician,
        builder: (context, state) => BlocProvider<FindClinicianBloc>(
          create: (_) =>
              getIt<FindClinicianBloc>()..add(const FindClinicianStarted()),
          child: const FindClinicianPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.findSpecialists,
        builder: (context, state) => BlocProvider<FindClinicianBloc>(
          create: (_) =>
              getIt<FindClinicianBloc>()..add(const FindClinicianStarted()),
          child: const FindClinicianPage(mode: ClinicianSearchMode.specialists),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => BlocProvider<NotificationsBloc>(
          create: (_) =>
              getIt<NotificationsBloc>()..add(const NotificationsStarted()),
          child: const NotificationsPage(),
        ),
      ),
    ],
  );
}
