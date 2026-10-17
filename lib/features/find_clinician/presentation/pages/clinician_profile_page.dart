import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/failure.dart';
import '../../../../core/utils/appointments_changed.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/domain/appointment.dart';
import '../../../home/domain/provider.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';
import '../../../home/presentation/widgets/rating_badge.dart';
import '../../data/clinician_repository.dart';
import '../../domain/booking_request.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../widgets/clinician_unavailable_sheet.dart';
import '../widgets/slot_picker.dart';

/// A clinician's details and the booking form.
///
/// Takes the whole [Provider] rather than an id because this backend has no
/// clinician detail endpoint — only the browse list. Everything shown here
/// comes from the list row the caller already holds, plus
/// `/clinicians/<id>/slots/`. That is also why the screen is pushed with a
/// `MaterialPageRoute` instead of a go_router path: it cannot be entered
/// cold from a deep link, and pretending otherwise would give a route that
/// renders an empty page. Noted in docs/PROJECT_STATUS.md.
class ClinicianProfilePage extends StatelessWidget {
  const ClinicianProfilePage({
    required this.clinician,
    this.replacing,
    super.key,
  });

  final Provider clinician;

  /// The appointment this booking takes the place of — set when the
  /// patient chose another clinician because the first could not be
  /// reached. It is cancelled once the new booking is confirmed, so the
  /// patient is not left with two appointments for one need.
  final Appointment? replacing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookingBloc>(
      create: (_) {
        final replacesId = int.tryParse(replacing?.id ?? '');
        // A replacement needs the extra constructor argument, which the
        // two-parameter DI factory cannot carry.
        final bloc = replacesId == null
            ? getIt<BookingBloc>(
                param1: clinician, param2: BookingMode.scheduled)
            : BookingBloc(
                clinicianRepository: getIt<ClinicianRepository>(),
                clinician: clinician,
                replacesAppointmentId: replacesId,
              );
        return bloc..add(const BookingStarted());
      },
      child: ClinicianProfileView(replacing: replacing),
    );
  }
}

/// The page body, with no `BlocProvider` of its own — see
/// [FindClinicianView] for why this split exists.
class ClinicianProfileView extends StatelessWidget {
  const ClinicianProfileView({this.replacing, super.key});

  final Appointment? replacing;

  @override
  Widget build(BuildContext context) {
    // Whether the failure being listened to came from a booking attempt
    // (as opposed to slots failing to load). Set in listenWhen, which runs
    // just before the listener for the same change.
    var bookingWasRejected = false;

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Clinician', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<BookingBloc, BookingState>(
          listenWhen: (previous, current) {
            bookingWasRejected = previous.isSubmitting &&
                current.status == BookingStatus.ready &&
                current.failure != null;
            return previous.status != current.status ||
                previous.failure != current.failure;
          },
          listener: (context, state) {
            final failure = state.failure;
            if (failure != null) {
              if (bookingWasRejected && failure is! AuthFailure) {
                _offerAlternatives(context, state, failure, replacing);
              } else {
                AppToast.error(context, failure.message);
              }
              return;
            }
            if (state.status == BookingStatus.booked) {
              _finishBooking(context, state.booked, replacing);
            }
          },
          builder: (context, state) {
            final clinician = state.clinician;
            if (clinician == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(child: _Details(state: state, clinician: clinician)),
                _BookingBar(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Closes the screen after a confirmed booking.
///
/// When the booking replaced an earlier appointment, the server has already
/// cancelled that one in the same transaction (PT-C9) — or rejected the
/// whole request, in which case this is never reached.
void _finishBooking(
  BuildContext context,
  Appointment? booked,
  Appointment? replacing,
) {
  final name = booked?.provider.displayName;
  if (replacing != null && name != null && booked!.provider.id.isNotEmpty) {
    AppToast.info(
      context,
      'Booked with $name. Your earlier appointment with '
      '${replacing.provider.displayName} was cancelled.',
    );
  } else {
    AppToast.info(context, 'Appointment requested.');
  }
  _announceChange();
  Navigator.of(context).pop(true);
}

/// Tells the Home and Appointments tabs to reload. Absent in widget tests
/// that pump this page alone.
void _announceChange() {
  if (getIt.isRegistered<AppointmentsChanged>()) {
    getIt<AppointmentsChanged>().notify();
  }
}

/// A booking the server refused, or one that never reached it.
///
/// A connection problem offers a retry. Anything else (the slot was just
/// taken, the clinician went offline) says why and suggests other
/// clinicians, so the patient is not left at a dead end.
Future<void> _offerAlternatives(
  BuildContext context,
  BookingState state,
  Failure failure,
  Appointment? replacing,
) async {
  final clinician = state.clinician;
  final bloc = context.read<BookingBloc>();
  final navigator = Navigator.of(context);
  final connection = failure is NetworkFailure;

  final choice = await showClinicianUnavailableSheet(
    context,
    title: connection
        ? 'Your connection dropped'
        : 'Could not book ${clinician?.displayName ?? 'this clinician'}',
    message: failure.message,
    retryLabel: connection ? 'Try again' : null,
    suggestOthers: !connection,
    excludeClinicianId: clinician?.id,
    specialty: clinician?.specialty,
  );
  switch (choice) {
    case UnavailableRetry():
      bloc.add(const BookingSubmitted());
    case UnavailablePicked(clinician: final other):
      final booked = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ClinicianProfilePage(
            clinician: other,
            replacing: replacing,
          ),
        ),
      );
      // Booking the suggested clinician finishes this screen's job too.
      if (booked == true && navigator.mounted) navigator.pop(true);
    case null:
      break;
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state, required this.clinician});

  final BookingState state;
  final Provider clinician;

  @override
  Widget build(BuildContext context) {
    final fee = clinician.consultationFee;
    final rating = clinician.rating;
    final experience = clinician.experienceLabel;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Row(
            children: [
              AvatarCircle(
                name: clinician.displayName,
                showAvailabilityDot: true,
                isAvailable: clinician.isAvailable,
                size: 64,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      clinician.displayName,
                      style: AppTextStyles.h2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (clinician.specialty != null) ...[
                      const SizedBox(height: 2),
                      Text(clinician.specialty!,
                          style: AppTextStyles.bodyMuted),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (rating != null) RatingBadge(rating: rating),
                        if (experience != null)
                          Text(experience,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.muted,
                              )),
                        Text(
                          clinician.isAvailable ? 'Online now' : 'Offline',
                          style: AppTextStyles.caption.copyWith(
                            color: clinician.isAvailable
                                ? AppColors.success
                                : AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (fee != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Panel(
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.muted),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('Consultation fee', style: AppTextStyles.body),
                ),
                Text(
                  fee.formatted,
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Said plainly rather than left for the patient to discover: there
          // is no payment step in this app yet (no payments backend), so the
          // fee is information, not a charge they are about to incur.
          const Text(
            'You are not charged now. Payment is arranged with the clinician.',
            style: AppTextStyles.caption,
          ),
        ],
        if (clinician.bio != null && clinician.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: AppSpacing.sm),
                Text(clinician.bio!, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        // Optional, but the clinician accepts or declines from this alone —
        // without it they see a request with no idea what it's for.
        Text('What do you need help with?', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          initialValue: state.reason,
          maxLength: 255,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Chest pain when climbing stairs (optional)',
            counterText: '',
          ),
          onChanged: (value) => context.read<BookingBloc>().add(BookingReasonChanged(value)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ModeSelector(state: state),
        const SizedBox(height: AppSpacing.lg),
        if (state.mode == BookingMode.scheduled) _Availability(state: state),
      ],
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == BookingStatus.loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.hasNoSlots) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No scheduled times available',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This clinician has not published any availability. You can '
              'still send an on-demand request.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context
                  .read<BookingBloc>()
                  .add(const BookingModeChanged(BookingMode.onDemand)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.teal),
              ),
              child: Text(
                'Request on demand',
                style: AppTextStyles.body.copyWith(color: AppColors.tealText),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a day',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: AppSpacing.md),
        SlotPicker(
          slotsByDay: state.slotsByDay,
          selected: state.selectedSlot,
          onSelected: (slot) =>
              context.read<BookingBloc>().add(BookingSlotSelected(slot)),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BookingBloc>();
    return Row(
      children: [
        Expanded(
          child: _ModeTab(
            label: 'Pick a time',
            selected: state.mode == BookingMode.scheduled,
            onTap: () =>
                bloc.add(const BookingModeChanged(BookingMode.scheduled)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ModeTab(
            label: 'On demand',
            selected: state.mode == BookingMode.onDemand,
            onTap: () =>
                bloc.add(const BookingModeChanged(BookingMode.onDemand)),
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.lightTealTint : AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.tealText : AppColors.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final onDemand = state.mode == BookingMode.onDemand;
    final slot = state.selectedSlot;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Restates what the button will book, so the patient never has to
          // scroll back up to check before committing — and says why the
          // button is disabled instead of leaving it greyed out silently.
          if (!onDemand && !state.hasNoSlots) ...[
            Row(
              children: [
                Icon(
                  slot == null
                      ? Icons.touch_app_outlined
                      : Icons.event_available,
                  size: 18,
                  color: slot == null ? AppColors.muted : AppColors.tealText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    slot == null
                        ? 'Pick a day and time to continue'
                        : DateFormat('EEE d MMM · h:mm a').format(slot),
                    style: slot == null
                        ? AppTextStyles.bodyMuted
                        : AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // Disabled until the request the button would send is actually
              // valid — the state exposes one `request`, so the button's enabled
              // state and the payload can never disagree.
              onPressed: state.canSubmit
                  ? () =>
                      context.read<BookingBloc>().add(const BookingSubmitted())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                disabledBackgroundColor: AppColors.border,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      onDemand ? 'Request now' : 'Book appointment',
                      style: AppTextStyles.buttonLabel,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: child,
    );
  }
}
