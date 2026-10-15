import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/widgets/app_toast.dart';

/// Shows a short banner for each notification that arrives while the app
/// is open, so the patient sees it without opening the bell.
///
/// Sits above the router, so it shows toasts through the navigator's
/// context — the only one below an Overlay.
class LiveNotificationToasts extends StatefulWidget {
  const LiveNotificationToasts({
    required this.events,
    required this.navigatorKey,
    required this.child,
    this.shouldShow = _always,
    super.key,
  });

  final Stream<RealtimeEvent> events;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function(RealtimeNotification notification) shouldShow;
  final Widget child;

  static bool _always(RealtimeNotification _) => true;

  @override
  State<LiveNotificationToasts> createState() => _LiveNotificationToastsState();
}

class _LiveNotificationToastsState extends State<LiveNotificationToasts> {
  StreamSubscription<RealtimeEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.events
        .where((e) => e is RealtimeNotification)
        .cast<RealtimeNotification>()
        .where(widget.shouldShow)
        .listen(_show);
  }

  void _show(RealtimeNotification notification) {
    final context = widget.navigatorKey.currentContext;
    if (context == null || notification.title.isEmpty) return;
    AppToast.info(context, notification.title);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
