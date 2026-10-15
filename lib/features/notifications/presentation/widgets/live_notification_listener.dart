import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../calls/presentation/pages/incoming_call_page.dart';

/// Reacts to notifications that arrive while the app is open: an incoming
/// call opens the ringing screen, anything else shows a short banner so the
/// patient sees it without opening the bell.
///
/// Sits above the router, so it works through the navigator's context —
/// the only one below an Overlay.
class LiveNotificationListener extends StatefulWidget {
  const LiveNotificationListener({
    required this.events,
    required this.navigatorKey,
    required this.child,
    this.shouldShow = _always,
    super.key,
  });

  static const String incomingCallType = 'INCOMING_CALL';

  final Stream<RealtimeEvent> events;
  final GlobalKey<NavigatorState> navigatorKey;

  /// Whether a banner is worth showing — false for a message in the thread
  /// already on screen, for example.
  final bool Function(RealtimeNotification notification) shouldShow;
  final Widget child;

  static bool _always(RealtimeNotification _) => true;

  @override
  State<LiveNotificationListener> createState() =>
      _LiveNotificationListenerState();
}

class _LiveNotificationListenerState extends State<LiveNotificationListener> {
  StreamSubscription<RealtimeEvent>? _subscription;

  /// The call whose ringing screen is up, so a repeated push for it does
  /// not stack a second one.
  String? _ringing;

  @override
  void initState() {
    super.initState();
    _subscription = widget.events
        .where((e) => e is RealtimeNotification)
        .cast<RealtimeNotification>()
        .listen(_onNotification);
  }

  void _onNotification(RealtimeNotification notification) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    if (notification.type == LiveNotificationListener.incomingCallType) {
      final callId = notification.payload['call_id']?.toString();
      if (callId == null || callId == _ringing) return;
      _ringing = callId;
      unawaited(navigator
          .push<void>(MaterialPageRoute<void>(
            builder: (_) => IncomingCallPage(callId: callId),
          ))
          .whenComplete(() => _ringing = null));
      return;
    }

    if (notification.title.isEmpty || !widget.shouldShow(notification)) return;
    AppToast.info(navigator.context, notification.title);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
