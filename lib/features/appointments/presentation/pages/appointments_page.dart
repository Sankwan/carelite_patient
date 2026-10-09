import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../calls/presentation/pages/precall_page.dart';
import '../../../find_clinician/presentation/pages/clinician_profile_page.dart';
import '../../../find_clinician/presentation/widgets/clinician_unavailable_sheet.dart';
import '../../../home/domain/appointment.dart';
import '../bloc/appointments_bloc.dart';
import '../bloc/appointments_event.dart';
import '../bloc/appointments_state.dart';
import '../widgets/appointment_card.dart';

/// The patient's appointments, split into what they can still act on and
/// what is finished.
///
/// Cancel is the only lifecycle action a patient has here: confirm, start,
/// and complete are all clinician-only server-side
/// (`AppointmentViewSet._require_clinician_owner`), so offering them would
/// only produce 403s. See docs/PROJECT_STATUS.md.
class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The appointment a cancel just went through for, if any. Set in
    // listenWhen, which runs just before the listener for the same change.
    Appointment? justCancelled;

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Appointments', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<AppointmentsBloc, AppointmentsState>(
          listenWhen: (previous, current) {
            justCancelled = _cancelledBetween(previous, current);
            return justCancelled != null ||
                (previous.failure != current.failure &&
                    current.failure != null);
          },
          listener: (context, state) {
            final cancelled = justCancelled;
            if (cancelled != null) {
              _offerAnotherClinician(context, cancelled);
            } else if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
          },
          builder: (context, state) {
            if (state.status == AppointmentsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                _Tabs(state: state),
                Expanded(child: _List(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The appointment whose cancel the server has just confirmed, or null.
///
/// A cancel in flight has `cancellingId` set; it clears on both success and
/// refusal, so the row's own status is what tells them apart.
Appointment? _cancelledBetween(
  AppointmentsState previous,
  AppointmentsState current,
) {
  final id = previous.cancellingId;
  if (id == null || current.cancellingId != null) return null;
  for (final appointment in current.appointments) {
    if (appointment.id == id &&
        appointment.status == AppointmentStatus.cancelled) {
      return appointment;
    }
  }
  return null;
}

/// A cancelled appointment still leaves a patient who needed care: offer
/// someone else before they walk away with nothing booked.
Future<void> _offerAnotherClinician(
  BuildContext context,
  Appointment cancelled,
) async {
  final bloc = context.read<AppointmentsBloc>();
  final navigator = Navigator.of(context, rootNavigator: true);
  final choice = await showClinicianUnavailableSheet(
    context,
    title: 'Appointment cancelled',
    message: 'Would you like to see another clinician instead?',
    dismissLabel: 'No, thanks',
    excludeClinicianId: cancelled.provider.id,
    specialty: cancelled.provider.specialty,
  );
  if (choice case UnavailablePicked(:final clinician)) {
    final booked = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClinicianProfilePage(clinician: clinician),
      ),
    );
    if (booked == true) bloc.add(const AppointmentsRefreshed());
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.state});

  final AppointmentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AppointmentsBloc>();
    final upcoming = state.upcomingCount;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _Tab(
            label: upcoming > 0 ? 'Upcoming ($upcoming)' : 'Upcoming',
            selected: state.filter == AppointmentsFilter.upcoming,
            onTap: () => bloc
                .add(const AppointmentsFilterChanged(AppointmentsFilter.upcoming)),
          ),
          const SizedBox(width: AppSpacing.xl),
          _Tab(
            label: 'Past',
            selected: state.filter == AppointmentsFilter.past,
            onTap: () =>
                bloc.add(const AppointmentsFilterChanged(AppointmentsFilter.past)),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.teal : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.ink : AppColors.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state});

  final AppointmentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AppointmentsBloc>();
    final visible = state.visible;

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const AppointmentsRefreshed()),
      child: ListView(
        // Always scrollable so an empty or failed list can still be pulled
        // to retry.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (visible.isEmpty)
            _EmptyState(state: state)
          else
            for (final appointment in visible) ...[
              AppointmentCard(
                appointment: appointment,
                isCancelling: state.cancellingId == appointment.id,
                onCancel: appointment.isCancellable
                    ? () => _confirmCancel(context, appointment)
                    : null,
                onJoin: appointment.isJoinable
                    ? () => Navigator.of(context, rootNavigator: true).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => PrecallPage(appointment: appointment),
                          ),
                        )
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  /// Asks first. Cancelling is destructive and cannot be undone from this
  /// app — there is no "un-cancel" endpoint.
  Future<void> _confirmCancel(
    BuildContext context,
    Appointment appointment,
  ) async {
    final bloc = context.read<AppointmentsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this appointment?'),
        content: Text(
          'Your appointment with ${appointment.provider.displayName} on '
          '${appointment.relativeLabel()} will be cancelled. '
          'This cannot be undone.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep it',
              style: AppTextStyles.body.copyWith(color: AppColors.ink),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancel appointment',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(AppointmentCancelled(appointment.id));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  final AppointmentsState state;

  @override
  Widget build(BuildContext context) {
    final upcoming = state.filter == AppointmentsFilter.upcoming;
    if (state.failure != null) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Could not load your appointments',
        body: state.failure!.message,
        actionLabel: 'Try again',
        onAction: () =>
            context.read<AppointmentsBloc>().add(const AppointmentsRefreshed()),
      );
    }
    return _Message(
      icon: upcoming ? Icons.event_available : Icons.history,
      title: upcoming ? 'No upcoming appointments' : 'No past appointments',
      body: upcoming
          ? 'When you book a consultation it will appear here.'
          : 'Completed and cancelled appointments will appear here.',
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.teal),
              ),
              child: Text(
                actionLabel!,
                style: AppTextStyles.body.copyWith(color: AppColors.tealText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
