import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../profile/presentation/pages/record_access_page.dart';
import '../../domain/app_notification.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';
import '../widgets/notification_card.dart';

/// The notifications feed (Figma 305:577), built against
/// `notifications.views.NotificationViewSet`.
///
/// Two departures from the design, both because the backend cannot support
/// what it drew: the card taxonomy is the server's five real types rather
/// than the invented lab/pharmacy-approval set (there is no patient-approval
/// step in this backend, and payments are deferred entirely), and the tab is
/// "Past" rather than a second identical "Today" — the design repeats one
/// card twice, which is a copy-paste artifact, not two notifications.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Notifications', style: AppTextStyles.h1),
        actions: [
          BlocBuilder<NotificationsBloc, NotificationsState>(
            buildWhen: (previous, current) =>
                previous.hasUnread != current.hasUnread,
            builder: (context, state) {
              if (!state.hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => context
                    .read<NotificationsBloc>()
                    .add(const NotificationsAllRead()),
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                child: Text(
                  'Mark all read',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<NotificationsBloc, NotificationsState>(
          listenWhen: (previous, current) => previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
          },
          builder: (context, state) {
            if (state.status == NotificationsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final visible = state.visible();
            return Column(
              children: [
                _FilterTabs(state: state),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => context
                        .read<NotificationsBloc>()
                        .add(const NotificationsRefreshed()),
                    child: visible.isEmpty
                        ? _EmptyState(filter: state.filter)
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) {
                              final notification = visible[index];
                              return NotificationCard(
                                notification: notification,
                                actionLabel: _actionLabelFor(notification),
                                onTap: () => _open(context, notification),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Only offer a button when there is somewhere real to send the patient.
  static String? _actionLabelFor(AppNotification notification) {
    return switch (notification.type) {
      NotificationType.resultReady => 'View result',
      NotificationType.clinicianAssigned => 'View appointment',
      NotificationType.incomingCall => 'Go to appointment',
      NotificationType.payment => null,
      // Only an access-request GENERIC has somewhere to go; others (none
      // today) fall through to null.
      NotificationType.generic =>
        notification.accessRequestId != null ? 'Review request' : null,
    };
  }

  void _open(BuildContext context, AppNotification notification) {
    context.read<NotificationsBloc>().add(NotificationRead(notification.id));
    switch (notification.type) {
      case NotificationType.resultReady:
        context.push(AppRoutes.medicalRecords);
      case NotificationType.clinicianAssigned:
      case NotificationType.incomingCall:
        context.push(AppRoutes.appointments);
      case NotificationType.generic:
        if (notification.accessRequestId != null) {
          Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute<void>(builder: (_) => const RecordAccessPage()),
          );
        }
      case NotificationType.payment:
        break;
    }
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.state});

  final NotificationsState state;

  @override
  Widget build(BuildContext context) {
    final todayCount = state.todayCount();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _Tab(
            label: todayCount > 0 ? 'Today ($todayCount)' : 'Today',
            selected: state.filter == NotificationsFilter.today,
            onTap: () => context
                .read<NotificationsBloc>()
                .add(const NotificationsFilterChanged(NotificationsFilter.today)),
          ),
          const SizedBox(width: AppSpacing.xl),
          _Tab(
            label: 'Past',
            selected: state.filter == NotificationsFilter.past,
            onTap: () => context
                .read<NotificationsBloc>()
                .add(const NotificationsFilterChanged(NotificationsFilter.past)),
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
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.blue : AppColors.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final NotificationsFilter filter;

  @override
  Widget build(BuildContext context) {
    // Must stay scrollable: RefreshIndicator cannot be pulled otherwise, so
    // an empty feed would have no way to retry.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const Icon(Icons.notifications_none_rounded,
            size: 56, color: AppColors.muted),
        const SizedBox(height: AppSpacing.lg),
        Text(
          filter == NotificationsFilter.today
              ? 'Nothing new today'
              : 'No earlier notifications',
          style: AppTextStyles.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Updates about your consultations, results and appointments will '
          'appear here.',
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
