import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../calls/presentation/pages/precall_page.dart';
import '../../../find_clinician/presentation/pages/clinician_profile_page.dart';
import '../../../location/data/location_repository.dart';
import '../../domain/provider.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/home_header.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/home_section_empty.dart';
import '../widgets/provider_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/recent_activity_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/upcoming_appointment_card.dart';

/// The patient dashboard (Figma 152:582), in two states.
///
/// Which one renders is derived from data, not from a flag: a patient with
/// no appointments is shown neither an "Upcoming Appointment" hero nor a
/// Recent Activity list (requirement #6).
///
/// There is deliberately no "Nearby Labs & Pharmacies" section here, despite
/// the Figma frame. Diagnostics are clinician-initiated: a lab request is
/// ordered during a consultation, the patient approves and pays, and only
/// then are nearby labs offered — see docs/PRODUCT_PATHWAY.md. Letting a
/// patient walk straight to a lab from Home would skip the clinician who
/// orders and interprets the test.
/// A clinician list takes that space so the first thing any patient sees
/// is a doctor to book (agreed, Sep 2026). Titled "Top clinicians", not
/// "near you": `ClinicianProfile` carries no location at all (consultations
/// are virtual), so the list the server returns is ordered by rating, never
/// distance — see `Provider.fromClinicianJson` and
/// docs/PROJECT_STATUS.md. "Near you" would be a claim this screen
/// cannot back up.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<HomeBloc, HomeState>(
          listenWhen: (previous, current) => previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
          },
          builder: (context, state) {
            if (state.status == HomeStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<HomeBloc>().add(const HomeRefreshed()),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  HomeHeader(
                    greeting: state.greeting(),
                    name: state.firstName,
                    avatarLabel: state.avatarLabel,
                    // A real place name once the on-device geocoder resolves
                    // one; "Near you" is the fallback for the gap between
                    // "we have coordinates" and "we could name them" — never
                    // blank while the patient has actually granted access.
                    locationLabel: state.hasLocation
                        ? (state.locationLabel ?? 'Near you')
                        : null,
                    onEnableLocation: () => _enableLocation(context),
                    hasUnreadNotifications: state.unreadNotifications > 0,
                    onNotificationsPressed: () async {
                      await context.push(AppRoutes.notifications);
                      // Reading notifications changes the badge, so refresh
                      // on the way back rather than showing a count the
                      // patient has already cleared.
                      if (context.mounted) {
                        context.read<HomeBloc>().add(const HomeRefreshed());
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HomeSearchBar(
                    onSearchPressed: () => openFindClinician(context),
                    onFilterPressed: () => openFindClinician(context),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Returning patients only.
                  if (state.upcoming != null) ...[
                    UpcomingAppointmentCard(
                      appointment: state.upcoming!,
                      // Joinable: straight to the pre-call checklist, the
                      // same screen the Appointments tab opens. Otherwise
                      // there is nothing to join yet, so show the
                      // appointment where it can be viewed or cancelled.
                      onJoin: state.upcoming!.isJoinable
                          ? () => Navigator.of(context, rootNavigator: true)
                              .push<void>(MaterialPageRoute<void>(
                                builder: (_) =>
                                    PrecallPage(appointment: state.upcoming!),
                              ))
                          : () => context.go(AppRoutes.appointments),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  const _QuickActions(),
                  const SizedBox(height: AppSpacing.xl),

                  // Shown to every patient, new or returning: for a brand-new
                  // one this is the main content of the dashboard.
                  _CliniciansNearYou(state: state),

                  if (state.recentActivity.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _RecentActivity(state: state),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Provides [HomeBloc] and kicks off the load with the signed-in patient's
/// identity. Split from [HomePage] so the page itself needs no auth
/// dependency and can be widget-tested with a plain Bloc.
class HomePageLoader extends StatelessWidget {
  const HomePageLoader({required this.createBloc, super.key});

  final HomeBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    return BlocProvider<HomeBloc>(
      create: (_) => createBloc()
        ..add(HomeStarted(
          patientId: user?.id ?? '',
          patientName: user?.fullName,
          patientUsername: user?.username,
        )),
      child: const HomePage(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What do you need today?', style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.md),
        QuickActionCard(
          title: 'General Care',
          subtitle: 'Search for a Doctor to Attend to You',
          isHighlighted: true,
          onTap: () => openFindClinician(context),
        ),
        const SizedBox(height: AppSpacing.md),
        QuickActionCard(
          title: 'Find Specialists',
          subtitle: 'Search for a special needs Practitioner',
          onTap: () =>
              openFindClinician(context, route: AppRoutes.findSpecialists),
        ),
      ],
    );
  }
}

class _CliniciansNearYou extends StatelessWidget {
  const _CliniciansNearYou({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Top clinicians',
          onSeeAll: () => openFindClinician(context),
        ),
        if (state.nearbyClinicians.isEmpty)
          const HomeSectionEmpty(
            message: 'No clinicians are available right now.',
          )
        else
          for (final provider in state.nearbyClinicians) ...[
            ProviderCard(
              provider: provider,
              // Straight to this clinician, not into a search the patient
              // would have to repeat — the card already holds the whole
              // record the profile screen needs, which is just as well:
              // there is no endpoint to fetch one clinician by id.
              onTap: () => _openClinician(context, provider),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Activity',
          onSeeAll: () => context.go(AppRoutes.appointments),
        ),
        for (final appointment in state.recentActivity) ...[
          RecentActivityTile(
            appointment: appointment,
            onViewNotes: () => context.go(AppRoutes.medicalRecords),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Opens Find a Clinician and refreshes Home if the patient booked while
/// they were in there.
///
/// The Home branch of the shell is kept alive by `StatefulShellRoute.
/// indexedStack`, so returning to it does not rebuild HomeBloc — without
/// this, a patient who just booked would land back on a dashboard that
/// still says they have no upcoming appointment.
Future<void> openFindClinician(
  BuildContext context, {
  String route = AppRoutes.findClinician,
}) async {
  final bloc = context.read<HomeBloc>();
  final booked = await context.push<bool>(route);
  if (booked == true) bloc.add(const HomeRefreshed());
}

/// Asks for location again after an earlier "Maybe Later" or refusal. A
/// permanent refusal can only be undone in the OS settings, so that is where
/// it goes; the dashboard reloads so the place name appears straight away.
Future<void> _enableLocation(BuildContext context) async {
  final bloc = context.read<HomeBloc>();
  final repository = getIt<LocationRepository>();
  final access = (await repository.requestPermission())
      .when(ok: (value) => value, err: (_) => null);
  switch (access) {
    case LocationAccess.granted:
      bloc.add(const HomeRefreshed());
    case LocationAccess.deniedForever:
      await repository.openSettings();
    case LocationAccess.serviceDisabled:
      if (context.mounted) {
        AppToast.info(context, 'Turn on Location in your phone settings first.');
      }
    case LocationAccess.denied || null:
      break;
  }
}

Future<void> _openClinician(BuildContext context, Provider provider) async {
  final bloc = context.read<HomeBloc>();
  // rootNavigator: the profile is a focused booking task, so it covers the
  // shell's bottom nav exactly as Find a Clinician does. Pushing on the
  // shell's own navigator instead leaves the tab bar visible underneath,
  // inviting the patient to wander off mid-booking.
  final booked = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ClinicianProfilePage(clinician: provider),
    ),
  );
  if (booked == true) bloc.add(const HomeRefreshed());
}
