import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../../../core/utils/result.dart';
import '../../../location/data/location_repository.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../data/appointment_repository.dart';
import '../../data/provider_repository.dart';
import '../../domain/appointment.dart';
import '../../domain/provider.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required AppointmentRepository appointmentRepository,
    required ProviderRepository providerRepository,
    required LocationRepository locationRepository,
    required NotificationRepository notificationRepository,
    Stream<void>? appointmentsChanged,
    Stream<void>? notificationsChanged,
  })  : _appointmentRepository = appointmentRepository,
        _providerRepository = providerRepository,
        _locationRepository = locationRepository,
        _notificationRepository = notificationRepository,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeUnreadChanged>(_onUnreadChanged);
    _changes = appointmentsChanged?.listen((_) => add(const HomeRefreshed()));
    _notifications =
        notificationsChanged?.listen((_) => add(const HomeUnreadChanged()));
  }

  StreamSubscription<void>? _changes;
  StreamSubscription<void>? _notifications;

  @override
  Future<void> close() {
    _changes?.cancel();
    _notifications?.cancel();
    return super.close();
  }

  Future<void> _onUnreadChanged(
    HomeUnreadChanged event,
    Emitter<HomeState> emit,
  ) async {
    final result = await _notificationRepository.fetchUnreadCount();
    result.when(
      ok: (count) => emit(state.copyWith(unreadNotifications: count)),
      err: (_) {},
    );
  }

  final AppointmentRepository _appointmentRepository;
  final ProviderRepository _providerRepository;
  final LocationRepository _locationRepository;
  final NotificationRepository _notificationRepository;

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(
      status: HomeStatus.loading,
      patientId: event.patientId,
      patientName: event.patientName,
      patientUsername: event.patientUsername,
      clearFailure: true,
    ));
    await _load(emit);
  }

  Future<void> _onRefreshed(HomeRefreshed event, Emitter<HomeState> emit) async {
    // No loading status on refresh: the dashboard already has content, and
    // blanking it to a spinner on pull-to-refresh is a worse experience than
    // letting the existing cards sit until the new data lands.
    emit(state.copyWith(clearFailure: true));
    await _load(emit);
  }

  Future<void> _load(Emitter<HomeState> emit) async {
    final patientId = state.patientId;
    if (patientId.isEmpty) return;

    // Location first: it decides whether providers come back with distances.
    // A refusal is not an error — it costs the distance labels and nothing
    // else, so the rest of the load proceeds either way.
    final coordinates = await _locationRepository.currentPosition().then(
          (result) => result.when(ok: (value) => value, err: (_) => null),
        );

    Result<Appointment?> upcoming;
    Result<List<Appointment>> recent;
    Result<List<Provider>> clinicians;
    int unread;
    String? locationLabel;
    try {
      final results = await Future.wait([
        _appointmentRepository.fetchUpcoming(patientId),
        _appointmentRepository.fetchRecent(patientId),
        _fetchProviders(coordinates, ProviderKind.clinician),
        _notificationRepository.fetchUnreadCount(),
        _fetchLocationLabel(coordinates),
      ]);
      upcoming = results[0] as Result<Appointment?>;
      recent = results[1] as Result<List<Appointment>>;
      clinicians = results[2] as Result<List<Provider>>;
      // Deliberately excluded from _firstFailure below: a badge that cannot
      // be counted is not worth putting an error in front of the patient
      // for. It simply stays at zero.
      unread = (results[3] as Result<int>)
          .when(ok: (value) => value, err: (_) => 0);
      // Same reasoning: a place name is decoration on the greeting, not
      // load-bearing. The header falls back to a generic label rather than
      // an error banner if this comes back null.
      locationLabel =
          (results[4] as Result<String?>).when(ok: (value) => value, err: (_) => null);
    } catch (e) {
      // Belt-and-braces: every repository this Bloc calls is now written to
      // convert a parse failure into Result.err rather than throw, but this
      // catch is what stops a *future* repository regression from
      // reproducing the exact bug that shipped here — an uncaught exception
      // (a null `scheduled_at` DateTime.parse, in that case) escaped through
      // this same Future.wait and left the Bloc on HomeStatus.loading
      // forever, with nothing in the UI to say why. Whatever throws next,
      // this turns it into a visible failure instead of a silent hang.
      final failure = UnexpectedFailure('Could not load your dashboard (${e.runtimeType}).');
      emit(state.copyWith(status: HomeStatus.ready, failure: failure));
      return;
    }

    // One failure should not blank the whole dashboard: each section falls
    // back to what it had, and the first real error is surfaced once.
    final failure = _firstFailure([upcoming, recent, clinicians]);

    emit(state.copyWith(
      status: HomeStatus.ready,
      upcoming: upcoming.when(ok: (value) => value, err: (_) => state.upcoming),
      clearUpcoming: upcoming.when(ok: (value) => value == null, err: (_) => false),
      recentActivity:
          recent.when(ok: (value) => value, err: (_) => state.recentActivity),
      nearbyClinicians:
          clinicians.when(ok: (value) => value, err: (_) => state.nearbyClinicians),
      hasLocation: coordinates != null,
      locationLabel: locationLabel,
      clearLocationLabel: coordinates == null,
      unreadNotifications: unread,
      failure: failure,
      clearFailure: failure == null,
    ));
  }

  /// Only clinicians are surfaced here. Labs and pharmacies are reached
  /// through a clinician's request, not browsed from Home — see the note on
  /// [HomePage]. The repository stays kind-agnostic so that flow can reuse it.
  Future<Result<List<Provider>>> _fetchProviders(
    Coordinates? coordinates,
    ProviderKind kind,
  ) {
    if (coordinates == null) {
      return _providerRepository.fetchVerified(kind: kind, limit: 5);
    }
    return _providerRepository.fetchNearby(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      kind: kind,
      limit: 5,
    );
  }

  /// A real place name for the header, or a fixed no-op result when there
  /// are no coordinates to resolve — kept as a Future so it can sit in the
  /// same `Future.wait` batch as everything else rather than serializing
  /// after it.
  Future<Result<String?>> _fetchLocationLabel(Coordinates? coordinates) {
    if (coordinates == null) return Future.value(const Result.ok(null));
    return _locationRepository.placeNameFor(coordinates);
  }

  Failure? _firstFailure(List<Result<dynamic>> results) {
    for (final result in results) {
      final failure = result.when(ok: (_) => null, err: (f) => f);
      if (failure != null) return failure;
    }
    return null;
  }
}
