import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'core/config/env.dart';
import 'core/network/api/api_client.dart';
import 'core/network/api/api_contract.dart';
import 'core/network/api/token_store.dart';
import 'core/realtime/realtime_client.dart';
import 'core/realtime/realtime_event.dart';
import 'core/realtime/realtime_session.dart';
import 'core/security/record_lock.dart';
import 'core/storage/app_preferences.dart';
import 'core/utils/appointments_changed.dart';
import 'core/utils/external_launcher.dart';
import 'features/appointments/presentation/bloc/appointments_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/django_auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/calls/data/call_repository.dart';
import 'features/calls/data/django_call_repository.dart';
import 'features/calls/presentation/bloc/call_bloc.dart';
import 'features/calls/presentation/bloc/incoming_call_bloc.dart';
import 'features/calls/presentation/bloc/precall_bloc.dart';
import 'features/find_clinician/data/clinician_repository.dart';
import 'features/find_clinician/data/django_clinician_repository.dart';
import 'features/find_clinician/domain/booking_request.dart';
import 'features/find_clinician/presentation/bloc/booking_bloc.dart';
import 'features/find_clinician/presentation/bloc/find_clinician_bloc.dart';
import 'features/home/data/appointment_repository.dart';
import 'features/home/data/django_appointment_repository.dart';
import 'features/home/data/django_provider_repository.dart';
import 'features/home/data/provider_repository.dart';
import 'features/home/domain/provider.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/location/data/location_repository.dart';
import 'features/location/presentation/bloc/location_bloc.dart';
import 'features/medical_records/data/django_records_repository.dart';
import 'features/medical_records/data/django_vitals_repository.dart';
import 'features/medical_records/data/records_repository.dart';
import 'features/medical_records/data/vitals_repository.dart';
import 'features/medical_records/domain/consultation.dart';
import 'features/medical_records/presentation/bloc/records_bloc.dart';
import 'features/medical_records/presentation/bloc/vitals_bloc.dart';
import 'features/messages/data/django_messaging_repository.dart';
import 'features/messages/data/messaging_repository.dart';
import 'features/messages/domain/open_conversation.dart';
import 'features/messages/presentation/bloc/conversations_bloc.dart';
import 'features/messages/presentation/bloc/messages_badge_bloc.dart';
import 'features/messages/presentation/bloc/thread_bloc.dart';
import 'features/notifications/data/django_notification_repository.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/notifications/presentation/bloc/notifications_bloc.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'features/profile/data/access_repository.dart';
import 'features/profile/data/django_access_repository.dart';
import 'features/profile/data/django_profile_repository.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/bloc/access_requests_bloc.dart';
import 'features/profile/presentation/bloc/change_password_bloc.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/profile/presentation/bloc/profile_setup_bloc.dart';

final GetIt getIt = GetIt.instance;

final _log = Logger('Bootstrap');

/// Runs [builder] (normally `() => const App()`) inside a guarded zone with
/// logging, env validation and DI registration done first — so `main.dart`
/// stays a two-line entry point and every environment misconfiguration
/// surfaces as one clear log line instead of a buried exception deep in a
/// widget build.
///
/// Every repository is served by the Django API. Supabase is gone entirely —
/// see docs/PROJECT_STATUS.md for which endpoints are live and which are
/// still stubs awaiting the backend.
Future<void> bootstrap(Widget Function() builder) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _setUpLogging();

      if (!Env.isConfigured) {
        // Fails loud and early rather than letting every request throw a
        // confusing "invalid URL" deep in a repository later.
        throw StateError(
          'Missing DJANGO_API_BASE_URL. Run with '
          '--dart-define=DJANGO_API_BASE_URL=http://10.0.2.2:8000 '
          '(see .env.example).',
        );
      }

      // Resolved before runApp so the router's `redirect` can read the
      // onboarding/location flags synchronously — a redirect cannot await.
      _registerDependencies(await AppPreferences.resolve());

      runApp(builder());
    },
    (error, stackTrace) {
      _log.severe('Uncaught error', error, stackTrace);
    },
  );
}

void _setUpLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '[${record.level.name}] ${record.loggerName}: ${record.message}');
    // record.error/stackTrace were being silently dropped — every
    // runZonedGuarded catch (below) logs 'Uncaught error' with the real
    // exception attached, but nothing ever printed it, so the log line was
    // just as blank as the stuck screen it was meant to explain.
    if (record.error != null) {
      debugPrint('  error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  stackTrace:\n${record.stackTrace}');
    }
  });
}

void _registerDependencies(AppPreferences preferences) {
  getIt.registerSingleton<AppPreferences>(preferences);
  getIt.registerLazySingleton<RecordLock>(() => RecordLock(preferences));

  // Auth is Django's, exclusively. SupabaseAuthRepository is gone: leaving
  // both registered would mean two identity systems issuing tokens for the
  // same user.
  getIt.registerLazySingleton<TokenStore>(
    () => const TokenStore(TokenStore.defaultStorage),
  );

  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(tokenStore: getIt<TokenStore>()),
  );

  // One socket for the app. A 4001 close means the access token expired;
  // any authenticated request makes ApiClient refresh it.
  getIt.registerLazySingleton<RealtimeClient>(
    () => WebSocketRealtimeClient(
      tokenStore: getIt<TokenStore>(),
      refreshSession: () => getIt<ApiClient>().get(ApiContract.currentUser),
    ),
  );
  Stream<RealtimeEvent> live() => getIt<RealtimeClient>().events;

  getIt.registerLazySingleton<AuthRepository>(
    () => DjangoAuthRepository(
      client: getIt<ApiClient>(),
      tokenStore: getIt<TokenStore>(),
    ),
  );

  getIt.registerLazySingleton<OnboardingRepository>(
    () => PreferencesOnboardingRepository(getIt<AppPreferences>()),
  );

  getIt.registerLazySingleton<ProfileRepository>(
    () => DjangoProfileRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<LocationRepository>(
    GeolocatorLocationRepository.new,
  );

  getIt.registerLazySingleton<AppointmentRepository>(
    () => DjangoAppointmentRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ProviderRepository>(
    () => DjangoProviderRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<NotificationRepository>(
    () => DjangoNotificationRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<AppointmentsChanged>(AppointmentsChanged.new);
  getIt.registerLazySingleton<RealtimeSession>(
    () => RealtimeSession(
      client: getIt<RealtimeClient>(),
      appointmentsChanged: getIt<AppointmentsChanged>(),
    ),
  );
  getIt.registerLazySingleton<ExternalLauncher>(
    () => const UrlExternalLauncher(),
  );
  getIt.registerLazySingleton<MessagingRepository>(
    () => DjangoMessagingRepository(
      getIt<ApiClient>(),
      currentUserId: () async => getIt<AuthBloc>().state.user?.id,
    ),
  );
  getIt.registerLazySingleton<OpenConversation>(OpenConversation.new);
  getIt.registerFactory<ConversationsBloc>(
    () => ConversationsBloc(
      messagingRepository: getIt<MessagingRepository>(),
      messagesChanged: live().messagesChanged,
    ),
  );
  getIt.registerFactoryParam<ThreadBloc, String, void>(
    (conversationId, _) => ThreadBloc(
      messagingRepository: getIt<MessagingRepository>(),
      conversationId: conversationId,
      messageArrived: live().conversationChanges(conversationId),
    ),
  );
  // The tab bar outlives every screen, so its badge does too.
  getIt.registerLazySingleton<MessagesBadgeBloc>(
    () => MessagesBadgeBloc(
      messagingRepository: getIt<MessagingRepository>(),
      messagesChanged: live().messagesChanged,
    ),
  );
  getIt.registerLazySingleton<ClinicianRepository>(
    () => DjangoClinicianRepository(
      getIt<ApiClient>(),
      location: getIt<LocationRepository>(),
    ),
  );

  getIt.registerLazySingleton<RecordsRepository>(
    () => DjangoRecordsRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<VitalsRepository>(
    () => DjangoVitalsRepository(
      getIt<ApiClient>(),
      currentUserId: () async => getIt<AuthBloc>().state.user?.id,
    ),
  );

  getIt.registerLazySingleton<AccessRepository>(
    () => DjangoAccessRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<CallRepository>(
    () => DjangoCallRepository(getIt<ApiClient>()),
  );

  // registerFactory, not a Singleton: each of these drives one screen in
  // the signup funnel and must start from a clean state if the user comes
  // back to it (e.g. re-running profile setup after a failed save).
  getIt.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(onboardingRepository: getIt<OnboardingRepository>()),
  );

  getIt.registerFactory<ProfileSetupBloc>(
    () => ProfileSetupBloc(profileRepository: getIt<ProfileRepository>()),
  );

  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(
      appointmentRepository: getIt<AppointmentRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      locationRepository: getIt<LocationRepository>(),
      notificationRepository: getIt<NotificationRepository>(),
      profileRepository: getIt<ProfileRepository>(),
      appointmentsChanged: getIt<AppointmentsChanged>().stream,
      notificationsChanged: live().notificationsChanged,
    ),
  );

  getIt.registerFactory<FindClinicianBloc>(
    () => FindClinicianBloc(clinicianRepository: getIt<ClinicianRepository>()),
  );

  // registerFactoryParam, not a plain Factory: one BookingBloc drives both
  // booking paths, and which one it is depends entirely on its parameters —
  // a clinician (book this person) or null (let the server match anyone).
  getIt.registerFactoryParam<BookingBloc, Provider?, BookingMode?>(
    (clinician, mode) => BookingBloc(
      clinicianRepository: getIt<ClinicianRepository>(),
      clinician: clinician,
      mode: mode ?? BookingMode.scheduled,
    ),
  );

  getIt.registerFactory<AppointmentsBloc>(
    () => AppointmentsBloc(
      appointmentRepository: getIt<AppointmentRepository>(),
      appointmentsChanged: getIt<AppointmentsChanged>().stream,
    ),
  );

  getIt.registerFactory<RecordsBloc>(
    () => RecordsBloc(recordsRepository: getIt<RecordsRepository>()),
  );

  getIt.registerFactory<VitalsBloc>(
    () => VitalsBloc(vitalsRepository: getIt<VitalsRepository>()),
  );

  getIt.registerFactory<AccessRequestsBloc>(
    () => AccessRequestsBloc(accessRepository: getIt<AccessRepository>()),
  );

  // Parameterised: one detail Bloc per opened consultation, because the
  // record it loads is that consultation's.
  getIt.registerFactoryParam<RecordDetailBloc, Consultation, void>(
    (consultation, _) => RecordDetailBloc(
      recordsRepository: getIt<RecordsRepository>(),
      consultation: consultation,
    ),
  );

  // Parameterised on the appointment id: both the checklist and the call
  // itself are scoped to one appointment.
  getIt.registerFactoryParam<PrecallBloc, String, void>(
    (appointmentId, _) => PrecallBloc(
      callRepository: getIt<CallRepository>(),
      appointmentId: appointmentId,
    ),
  );

  getIt.registerFactoryParam<CallBloc, String, void>(
    (appointmentId, _) => CallBloc(
      callRepository: getIt<CallRepository>(),
      appointmentId: appointmentId,
      callChanged: live().callChanges,
    ),
  );

  // Parameterised on the call id: one ringing call per screen.
  getIt.registerFactoryParam<IncomingCallBloc, String, void>(
    (callId, _) => IncomingCallBloc(
      callRepository: getIt<CallRepository>(),
      appointmentRepository: getIt<AppointmentRepository>(),
      callId: callId,
      callChanged: live().callChanges,
    ),
  );

  getIt.registerFactory<ProfileBloc>(
    () => ProfileBloc(profileRepository: getIt<ProfileRepository>()),
  );

  getIt.registerFactory<ChangePasswordBloc>(
    () => ChangePasswordBloc(authRepository: getIt<AuthRepository>()),
  );

  getIt.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(
      notificationRepository: getIt<NotificationRepository>(),
      notificationsChanged: live().notificationsChanged,
    ),
  );

  getIt.registerFactory<LocationBloc>(
    () => LocationBloc(
      locationRepository: getIt<LocationRepository>(),
      preferences: getIt<AppPreferences>(),
    ),
  );

  // registerLazySingleton, not a Factory: the app needs exactly one AuthBloc
  // for its lifetime so route redirects and every BlocBuilder observe the
  // same auth state.
  getIt.registerLazySingleton<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>())
      ..add(const AuthSubscriptionRequested()),
  );
}
