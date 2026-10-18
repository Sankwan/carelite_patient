import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/appointments_changed.dart';
import 'realtime_client.dart';
import 'realtime_event.dart';

/// Keeps the socket open exactly while someone is signed in and the app is
/// in the foreground, and turns server events into the app's own signals.
///
/// Mobile OSes drop sockets of backgrounded apps, so the socket is closed
/// on pause and reopened on resume; the [RealtimeReconnected] that follows
/// tells every listening screen to catch up on what it missed.
class RealtimeSession with WidgetsBindingObserver {
  RealtimeSession({
    required RealtimeClient client,
    required AppointmentsChanged appointmentsChanged,
  })  : _client = client,
        _appointmentsChanged = appointmentsChanged;

  /// Notification types that mean an appointment's state moved on.
  static const Set<String> appointmentTypes = {
    'CLINICIAN_ASSIGNED',
    'APPOINTMENT_CANCELLED',
    'APPOINTMENT_CONFIRMED',
    'CONSULTATION_STARTED',
    'CONSULTATION_COMPLETED',
    'APPOINTMENT_MISSED',
    'CALL_MISSED',
    // A call starting or ending moves the appointment on too.
    'INCOMING_CALL',
  };

  final RealtimeClient _client;
  final AppointmentsChanged _appointmentsChanged;
  StreamSubscription<RealtimeEvent>? _events;
  bool _signedIn = false;
  bool _observing = false;

  /// Starts or stops the connection to follow sign-in state.
  void signedInChanged({required bool signedIn}) {
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;
    if (signedIn) {
      _events ??= _client.events.listen(_onEvent);
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      _client.connect();
    } else {
      unawaited(_client.disconnect(endSession: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_signedIn) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _client.connect();
      case AppLifecycleState.paused:
        unawaited(_client.disconnect());
      case _:
        break;
    }
  }

  void _onEvent(RealtimeEvent event) {
    final appointmentsMoved = switch (event) {
      RealtimeReconnected() => true,
      RealtimeNotification(:final type) => appointmentTypes.contains(type),
      _ => false,
    };
    if (appointmentsMoved) _appointmentsChanged.notify();
  }

  Future<void> dispose() async {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    await _events?.cancel();
    await _client.disconnect(endSession: true);
  }
}
