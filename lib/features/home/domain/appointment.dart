import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import 'provider.dart';

/// Mirrors `appointments.models.Appointment.Status` — verified against the
/// live Django backend (a fresh booking comes back `"status": "REQUESTED"`).
enum AppointmentStatus { requested, confirmed, inProgress, completed, cancelled }

/// Where an appointment stands against the clock — the same rule the
/// clinician app uses, so both sides agree on when a visit is open or missed.
enum VisitTiming { early, open, missed, live, closed }

/// The backend has no consultation-kind field on Appointment at all — a
/// video/voice choice lives on `calls.CallSession`, one level down, created
/// only once a call is actually initiated. There is nothing to read it from
/// ahead of that, and no in-person option exists anywhere in this backend
/// (every consultation is virtual). [Appointment.consultationType] is
/// therefore always [video] until a call has started; kept as its own type
/// rather than removed so the call-session mapping has somewhere to land.
enum ConsultationKind {
  video('Video Consultation'),
  voice('Voice Consultation');

  const ConsultationKind(this.label);

  final String label;
}

class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.provider,
    required this.scheduledFor,
    required this.status,
    this.consultationType = ConsultationKind.video,
    this.escrowStatus,
    this.notes,
    this.consultationId,
    this.activeCallId,
    this.requestedAt,
    this.isOnDemand = false,
  });

  /// Parses `appointments.serializers.AppointmentSerializer`'s shape —
  /// verified live: booked a real appointment and read it back.
  factory Appointment.fromDjangoJson(Map<String, dynamic> row) {
    final clinician = row['clinician'] as Map<String, dynamic>?;
    return Appointment(
      id: '${row['id']}',
      // `clinician` is nullable on the backend (ANY-booking assignment,
      // or SET_NULL if that user is later removed). Booking validation
      // means this is rare in practice; when it does happen, showing a
      // clearly-labelled placeholder beats crashing on a null provider.
      provider: clinician != null
          ? Provider.fromClinicianJson(clinician)
          : const Provider(
              id: '',
              kind: ProviderKind.clinician,
              displayName: 'Clinician unavailable',
            ),
      // scheduled_at is genuinely nullable — Appointment.mode ON_DEMAND
      // clears it server-side ("book any available clinician right now"),
      // it isn't a data gap. This is a real, reachable case, not a defensive
      // guess: it crashed Home outright the first time an ON_DEMAND booking
      // showed up, because DateTime.parse(null as String) throws a plain
      // TypeError, not a DioException — the only kind the repository's
      // catch was written for — so it went uncaught, straight through
      // Future.wait, and left the Bloc stuck on HomeStatus.loading forever
      // with the real cause silently dropped by a logger that (also, until
      // just now) discarded its error/stackTrace arguments.
      //
      // created_at is a fair stand-in: for an on-demand request there is no
      // "scheduled" moment, only "when it was requested" — a real value
      // from the row, not a fabricated one.
      scheduledFor: DateTime.parse(
        (row['scheduled_at'] ?? row['created_at']) as String,
      ).toLocal(),
      status: _statusFrom(row['status'] as String),
      consultationId: row['consultation_id']?.toString(),
      activeCallId: row['active_call_id']?.toString(),
      requestedAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal(),
      isOnDemand: row['mode'] == 'ON_DEMAND' || row['scheduled_at'] == null,
      // escrowStatus and notes are left at their null defaults: no
      // payments/escrow exist in this backend (Increment 7 explicitly
      // deferred), and consultation notes are a separate versioned resource
      // this repository does not fetch.
    );
  }

  final String id;
  final Provider provider;
  final DateTime scheduledFor;
  final AppointmentStatus status;
  final ConsultationKind consultationType;

  /// Read-only display only. No backend in this migration computes or
  /// stores escrow state — see the class doc.
  final String? escrowStatus;
  final String? notes;

  /// Set once the clinician has started the consultation.
  final String? consultationId;

  /// A call ringing or connected right now.
  final String? activeCallId;
  final DateTime? requestedAt;

  /// "See a clinician now" rather than a booked slot.
  final bool isOnDemand;

  /// The patient can get ready this long before the booked time.
  static const Duration opensBefore = Duration(minutes: 10);

  /// Agreed no-show rule: 15 minutes past the booked time with nobody
  /// started, the visit counts as missed.
  static const Duration missedAfter = Duration(minutes: 15);

  DateTime get dueAt => isOnDemand ? (requestedAt ?? scheduledFor) : scheduledFor;
  DateTime get opensAt => isOnDemand ? dueAt : dueAt.subtract(opensBefore);
  DateTime get missedAt => dueAt.add(missedAfter);

  VisitTiming timingAt(DateTime now) => switch (status) {
        AppointmentStatus.inProgress => VisitTiming.live,
        AppointmentStatus.completed || AppointmentStatus.cancelled => VisitTiming.closed,
        _ when now.isAfter(missedAt) => VisitTiming.missed,
        _ when now.isBefore(opensAt) => VisitTiming.early,
        _ => VisitTiming.open,
      };

  /// REQUESTED means booked but not yet confirmed by the clinician — showing
  /// a live "Join Call" for it would let a patient try to join a call no
  /// clinician has agreed to. A confirmed visit is joinable only inside its
  /// window; once missed, there is nothing left to join.
  bool get isJoinable => isJoinableAt(DateTime.now());

  bool isJoinableAt(DateTime now) {
    final timing = timingAt(now);
    return timing == VisitTiming.live ||
        (status == AppointmentStatus.confirmed && timing == VisitTiming.open);
  }

  /// The patient's button for this appointment at [now], or null.
  String? joinLabelAt(DateTime now) => switch ((status, timingAt(now))) {
        (_, VisitTiming.live) => 'Rejoin consultation',
        (AppointmentStatus.confirmed, VisitTiming.open) => 'I\'m ready',
        _ => null,
      };

  /// Still live: the patient can act on it. Used to split the Appointments
  /// screen's two tabs, so that together they account for every appointment
  /// and none can fall between them.
  bool get isActive =>
      status == AppointmentStatus.requested ||
      status == AppointmentStatus.confirmed ||
      status == AppointmentStatus.inProgress;

  /// The server rejects a cancel once an appointment is COMPLETED or
  /// CANCELLED (`appointments.views.AppointmentViewSet.cancel`), so the
  /// action is hidden rather than offered and then refused.
  bool get isCancellable => isActive;

  /// What the status chip reads. Deliberately the patient's wording, not the
  /// wire value: REQUESTED means "the clinician has not accepted yet", which
  /// "Requested" alone does not convey.
  String get statusLabel => statusLabelAt(DateTime.now());

  String statusLabelAt(DateTime now) => switch ((status, timingAt(now))) {
        (AppointmentStatus.requested, VisitTiming.missed) => 'Not accepted in time',
        (AppointmentStatus.confirmed, VisitTiming.missed) => 'Missed',
        _ => _baseStatusLabel,
      };

  String get _baseStatusLabel => switch (status) {
        AppointmentStatus.requested => 'Awaiting confirmation',
        AppointmentStatus.confirmed => 'Confirmed',
        AppointmentStatus.inProgress => 'In progress',
        AppointmentStatus.completed => 'Completed',
        AppointmentStatus.cancelled => 'Cancelled',
      };

  /// "Today · 2:30 PM", "Tomorrow · 9:00 AM", else "Wed, 4 Sep · 2:30 PM".
  ///
  /// Always computed from [scheduledFor] — never a hardcoded weekday string.
  String relativeLabel({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(scheduledFor.year, scheduledFor.month, scheduledFor.day);
    final time = DateFormat('h:mm a').format(scheduledFor);

    final difference = day.difference(today).inDays;
    return switch (difference) {
      0 => 'Today · $time',
      1 => 'Tomorrow · $time',
      -1 => 'Yesterday · $time',
      _ => '${DateFormat('EEE, d MMM').format(scheduledFor)} · $time',
    };
  }

  Appointment copyWith({AppointmentStatus? status}) {
    return Appointment(
      id: id,
      provider: provider,
      scheduledFor: scheduledFor,
      status: status ?? this.status,
      consultationType: consultationType,
      escrowStatus: escrowStatus,
      notes: notes,
      consultationId: consultationId,
      activeCallId: activeCallId,
      requestedAt: requestedAt,
      isOnDemand: isOnDemand,
    );
  }

  static AppointmentStatus _statusFrom(String value) {
    return switch (value) {
      'REQUESTED' => AppointmentStatus.requested,
      'CONFIRMED' => AppointmentStatus.confirmed,
      'IN_PROGRESS' => AppointmentStatus.inProgress,
      'COMPLETED' => AppointmentStatus.completed,
      'CANCELLED' => AppointmentStatus.cancelled,
      _ => AppointmentStatus.requested,
    };
  }

  @override
  List<Object?> get props =>
      [
        id, provider, scheduledFor, status, consultationType, escrowStatus, notes,
        consultationId, activeCallId, requestedAt, isOnDemand,
      ];
}
