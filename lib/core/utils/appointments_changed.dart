import 'dart:async';

/// Announces that the patient's appointments changed somewhere other than
/// the screen that lists them — a booking made from a call screen, say.
///
/// The Home and Appointments tabs are kept alive behind whatever is pushed
/// on top of them, so they do not rebuild when the patient comes back.
/// They listen here and reload instead of showing a stale list.
class AppointmentsChanged {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);
}
