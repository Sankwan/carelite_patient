import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/domain/provider.dart';
import '../../../home/presentation/widgets/provider_card.dart';
import '../../domain/booking_request.dart';
import '../../domain/search_filter.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../bloc/find_clinician_bloc.dart';
import '../bloc/find_clinician_event.dart';
import '../bloc/find_clinician_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/match_me_card.dart';
import '../widgets/specialty_search_field.dart';
import 'clinician_profile_page.dart';

/// Browse and filter verified clinicians, or let the server match one.
///
/// Filtering is entirely server-side (`?specialty=`, `?online=`) because the
/// list is paginated at 20: sorting or filtering the fetched page would give
/// answers that are wrong as soon as there are more clinicians than fit on
/// it. See docs/PROJECT_STATUS.md for what the design asked for that
/// the backend cannot do.
class FindClinicianPage extends StatelessWidget {
  const FindClinicianPage({this.mode = ClinicianSearchMode.general, super.key});

  final ClinicianSearchMode mode;

  @override
  Widget build(BuildContext context) {
    // The match action books an appointment, which is a different Bloc's job
    // from browsing. It lives here rather than on its own screen because
    // there is no intermediate state to show — the request either returns a
    // booked appointment or an error.
    return BlocProvider<BookingBloc>(
      create: (_) => getIt<BookingBloc>(param2: BookingMode.onDemand),
      child: FindClinicianView(mode: mode),
    );
  }
}

/// The page body, with no `BlocProvider` of its own.
///
/// Split out from [FindClinicianPage] so a test can inject both Blocs and
/// exercise exactly the tree that ships, rather than a copy of it that could
/// drift.
class FindClinicianView extends StatelessWidget {
  const FindClinicianView({this.mode = ClinicianSearchMode.general, super.key});

  final ClinicianSearchMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(mode.title, style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocListener<BookingBloc, BookingState>(
          listenWhen: (previous, current) =>
              previous.status != current.status ||
              previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
              return;
            }
            if (state.status == BookingStatus.booked && state.booked != null) {
              // The matched clinician's name is only knowable from the
              // response — an ANY booking has nobody attached until then.
              AppToast.info(
                context,
                'Matched with ${state.booked!.provider.displayName}.',
              );
              context.pop(true);
            }
          },
          child: BlocConsumer<FindClinicianBloc, FindClinicianState>(
            listenWhen: (previous, current) =>
                previous.failure != current.failure && current.failure != null,
            listener: (context, state) =>
                AppToast.error(context, state.failure!.message),
            builder: (context, state) => _Body(state: state, mode: mode),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.mode});

  final FindClinicianState state;
  final ClinicianSearchMode mode;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FindClinicianBloc>();
    final isSpecialists = mode == ClinicianSearchMode.specialists;

    return Column(
      children: [
        if (isSpecialists)
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
            ),
            child: SpecialtySearchField(
              initialValue: state.filter.specialty,
              onChanged: (value) =>
                  bloc.add(FindClinicianSpecialtyChanged(value)),
            ),
          ),
        Container(
          width: double.infinity,
          color: AppColors.white,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: FilterChipRow(
            filter: state.filter,
            specialties: isSpecialists ? kSpecialistChips : const [],
            onSpecialtySelected: (value) =>
                bloc.add(FindClinicianSpecialtyChanged(value)),
            onAvailabilityToggled: () =>
                bloc.add(const FindClinicianAvailabilityToggled()),
          ),
        ),
        Expanded(
          child: state.status == FindClinicianStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : _Results(state: state, mode: mode),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.mode});

  final FindClinicianState state;
  final ClinicianSearchMode mode;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FindClinicianBloc>();
    final booking = context.watch<BookingBloc>().state;
    final isSpecialists = mode == ClinicianSearchMode.specialists;
    // The backend can't exclude general practitioners from an unfiltered
    // list, so Find Specialists shows nothing until a specialty is chosen
    // rather than listing every clinician under a "specialists" title.
    final awaitingSpecialty =
        isSpecialists && state.filter.specialty.trim().isEmpty;

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const FindClinicianRetried()),
      child: ListView(
        // Always scrollable so an empty or failed list can still be pulled
        // to retry — a Column here would make the refresh gesture inert.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Match Me books whoever is free, regardless of specialty — right
          // for General Care, wrong for a patient who came looking for one.
          if (!isSpecialists) ...[
            MatchMeCard(
              isBusy: booking.isSubmitting,
              onPressed: () =>
                  context.read<BookingBloc>().add(const BookingSubmitted()),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (awaitingSpecialty)
            const _Message(
              icon: Icons.medical_services_outlined,
              title: 'Choose a specialty',
              body: 'Pick a specialty above, or type one, to see the '
                  'specialists who practise it.',
            )
          else ...[
            Text(
              state.filter.summaryLabel(state.clinicians.length),
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (awaitingSpecialty)
            const SizedBox.shrink()
          else if (state.clinicians.isEmpty)
            _EmptyState(state: state)
          else
            for (final clinician in state.clinicians) ...[
              ProviderCard(
                provider: clinician,
                onTap: () => _openProfile(context, clinician),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  /// The clinician object is passed rather than an id: this backend has no
  /// `GET /api/accounts/clinicians/<id>/`, so a profile screen that only
  /// knew an id would have no way to fetch the rest. That is also why this
  /// is a Navigator push and not a go_router path — the route could not be
  /// entered cold from a link.
  Future<void> _openProfile(BuildContext context, Provider clinician) async {
    final booked = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClinicianProfilePage(clinician: clinician),
      ),
    );
    if (booked == true && context.mounted) {
      context.pop(true);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  final FindClinicianState state;

  @override
  Widget build(BuildContext context) {
    if (state.failure != null) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Could not load clinicians',
        body: state.failure!.message,
        actionLabel: 'Try again',
        onAction: () =>
            context.read<FindClinicianBloc>().add(const FindClinicianRetried()),
      );
    }
    if (state.isEmptyBecauseOfFilters) {
      return _Message(
        icon: Icons.search_off,
        title: 'No clinicians match those filters',
        body: state.filter.onlineOnly
            ? 'Nobody with that specialty is online right now. Try clearing '
                'the filters, or book a scheduled appointment instead.'
            : 'No verified clinician lists that specialty yet.',
        actionLabel: 'Clear filters',
        onAction: () => context
            .read<FindClinicianBloc>()
            .add(const FindClinicianFiltersCleared()),
      );
    }
    return const _Message(
      icon: Icons.person_search,
      title: 'No clinicians available yet',
      body: 'No clinicians have been verified on CareLite yet. '
          'Please check back soon.',
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
