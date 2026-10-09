import 'package:flutter/material.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/domain/provider.dart';
import '../../../home/presentation/widgets/provider_card.dart';
import '../../data/clinician_repository.dart';
import '../../domain/search_filter.dart';

/// What the patient chose on the sheet. Dismissing it returns null.
sealed class UnavailableChoice {
  const UnavailableChoice();
}

/// "Try again" / "Keep waiting".
final class UnavailableRetry extends UnavailableChoice {
  const UnavailableRetry();
}

/// One of the suggested clinicians.
final class UnavailablePicked extends UnavailableChoice {
  const UnavailablePicked(this.clinician);

  final Provider clinician;
}

/// The clinicians offered in place of the one who is unavailable.
class ClinicianAlternatives {
  const ClinicianAlternatives({required this.clinicians, required this.onlineNow});

  final List<Provider> clinicians;

  /// False when nobody else is online and these are simply other
  /// clinicians the patient could book a time with.
  final bool onlineNow;
}

typedef AlternativesLoader = Future<ClinicianAlternatives> Function();

/// Finds up to [limit] other clinicians, most relevant first: online with
/// the same specialty, then anyone online, then anyone with the specialty.
///
/// A failed request is treated as "none found" — this runs after something
/// has already gone wrong, and a second error on top would help nobody.
Future<ClinicianAlternatives> loadClinicianAlternatives(
  ClinicianRepository repository, {
  String? excludeClinicianId,
  String? specialty,
  int limit = 3,
}) async {
  final wanted = specialty?.trim() ?? '';

  Future<List<Provider>> search(ClinicianFilter filter) async {
    final result = await repository.search(filter);
    return result.when(
      ok: (clinicians) => clinicians
          .where((c) => c.id != excludeClinicianId)
          .take(limit)
          .toList(growable: false),
      err: (_) => const <Provider>[],
    );
  }

  if (wanted.isNotEmpty) {
    final sameSpecialty =
        await search(ClinicianFilter(specialty: wanted, onlineOnly: true));
    if (sameSpecialty.isNotEmpty) {
      return ClinicianAlternatives(clinicians: sameSpecialty, onlineNow: true);
    }
  }
  final online = await search(const ClinicianFilter(onlineOnly: true));
  if (online.isNotEmpty) {
    return ClinicianAlternatives(clinicians: online, onlineNow: true);
  }
  final anyone = await search(ClinicianFilter(specialty: wanted));
  return ClinicianAlternatives(clinicians: anyone, onlineNow: false);
}

/// Says plainly what went wrong with a clinician and offers others.
///
/// Set [suggestOthers] to false for a connection problem: the fix is to
/// retry, and a clinician list could not load anyway.
Future<UnavailableChoice?> showClinicianUnavailableSheet(
  BuildContext context, {
  required String title,
  required String message,
  String? excludeClinicianId,
  String? specialty,
  String? retryLabel,
  String dismissLabel = 'Not now',
  bool suggestOthers = true,
  AlternativesLoader? loader,
}) {
  return showModalBottomSheet<UnavailableChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => ClinicianUnavailableSheet(
      title: title,
      message: message,
      retryLabel: retryLabel,
      dismissLabel: dismissLabel,
      loader: !suggestOthers
          ? null
          : loader ??
              () => loadClinicianAlternatives(
                    getIt<ClinicianRepository>(),
                    excludeClinicianId: excludeClinicianId,
                    specialty: specialty,
                  ),
    ),
  );
}

class ClinicianUnavailableSheet extends StatefulWidget {
  const ClinicianUnavailableSheet({
    required this.title,
    required this.message,
    this.retryLabel,
    this.dismissLabel = 'Not now',
    this.loader,
    super.key,
  });

  final String title;
  final String message;
  final String? retryLabel;
  final String dismissLabel;

  /// Null means no clinicians are suggested.
  final AlternativesLoader? loader;

  @override
  State<ClinicianUnavailableSheet> createState() =>
      _ClinicianUnavailableSheetState();
}

class _ClinicianUnavailableSheetState extends State<ClinicianUnavailableSheet> {
  late final Future<ClinicianAlternatives>? _alternatives = widget.loader?.call();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.message, style: AppTextStyles.bodyMuted),
            if (_alternatives != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FutureBuilder<ClinicianAlternatives>(
                future: _alternatives,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _Suggestions(
                    alternatives: snapshot.data ??
                        const ClinicianAlternatives(
                          clinicians: [],
                          onlineNow: false,
                        ),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (widget.retryLabel != null) ...[
              PrimaryButton(
                label: widget.retryLabel!,
                onPressed: () =>
                    Navigator.of(context).pop(const UnavailableRetry()),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text(
                  widget.dismissLabel,
                  style: AppTextStyles.body.copyWith(color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.alternatives});

  final ClinicianAlternatives alternatives;

  @override
  Widget build(BuildContext context) {
    if (alternatives.clinicians.isEmpty) {
      return const Text(
        'No other clinicians are available right now. Please try again '
        'in a little while.',
        style: AppTextStyles.bodyMuted,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          alternatives.onlineNow
              ? 'Available now'
              : 'Nobody else is online. You can book a time with:',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final clinician in alternatives.clinicians) ...[
          ProviderCard(
            provider: clinician,
            onTap: () =>
                Navigator.of(context).pop(UnavailablePicked(clinician)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
