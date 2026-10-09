import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/onboarding_slide.dart';
import '../widgets/pagination_dots.dart';

/// Slide copy is verbatim from the Figma onboarding frames (152:513 /
/// 152:496 / 152:342) — treat the design file as the source of truth for
/// this text rather than paraphrasing it here.
const List<({IconData icon, String title, String body})> _slides = [
  (
    icon: Icons.video_call_outlined,
    title: 'Have conversations with our health specialists',
    body: 'Book a video consultation with verified doctors from the comfort '
        'of your homes',
  ),
  (
    icon: Icons.location_on_outlined,
    title: 'Care that finds You',
    body: 'Access Pharmacies and Diagnostic centers near you wherever you '
        'are in Ghana.',
  ),
  (
    icon: Icons.verified_user_outlined,
    title: 'Secure, local, For your needs',
    body: 'Access to healthcare for all',
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocConsumer<OnboardingBloc, OnboardingState>(
          listenWhen: (previous, current) =>
              previous.status != current.status || previous.failure != current.failure,
          listener: (context, state) {
            if (state.failure != null) {
              AppToast.error(context, state.failure!.message);
            }
            if (state.status == OnboardingStatus.completed) {
              // The router's redirect owns where an onboarded user lands
              // (login vs. profile vs. home) — this only leaves onboarding.
              context.go(AppRoutes.login);
            }
          },
          builder: (context, state) {
            final isLast = state.isLastSlide;
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: OnboardingState.slideCount,
                    onPageChanged: (index) => context
                        .read<OnboardingBloc>()
                        .add(OnboardingSlideChanged(index)),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Semantics(
                        label: 'Slide ${index + 1} of '
                            '${OnboardingState.slideCount}',
                        child: OnboardingSlide(
                          illustration: slide.icon,
                          title: slide.title,
                          body: slide.body,
                        ),
                      );
                    },
                  ),
                ),
                PaginationDots(
                  count: OnboardingState.slideCount,
                  activeIndex: state.slideIndex,
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: isLast
                      ? PrimaryButton(
                          label: 'GET STARTED',
                          isLoading: state.status == OnboardingStatus.completing,
                          onPressed: () => _complete(context),
                        )
                      : _SkipNextRow(
                          onSkip: () => _complete(context),
                          onNext: _nextSlide,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _complete(BuildContext context) {
    context.read<OnboardingBloc>().add(const OnboardingCompleted());
  }

  void _nextSlide() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

class _SkipNextRow extends StatelessWidget {
  const _SkipNextRow({required this.onSkip, required this.onNext});

  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(
            'Skip',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: onNext,
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(
            'Next',
            style: AppTextStyles.body.copyWith(
              color: AppColors.tealText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
