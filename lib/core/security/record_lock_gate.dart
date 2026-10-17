import 'package:flutter/material.dart';

import '../../bootstrap.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'record_lock.dart';

/// Shows [child] only while the record lock allows it; otherwise a locked
/// screen with one button. With the lock off this is just [child].
class RecordLockGate extends StatelessWidget {
  const RecordLockGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Absent in widget tests that pump a record screen alone.
    if (!getIt.isRegistered<RecordLock>()) return child;
    final lock = getIt<RecordLock>();
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) => lock.isUnlocked ? child : const _Locked(),
    );
  }
}

class _Locked extends StatefulWidget {
  const _Locked();

  @override
  State<_Locked> createState() => _LockedState();
}

class _LockedState extends State<_Locked> {
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    // Ask straight away; the button is there if they cancel.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_asking) return;
    setState(() => _asking = true);
    await getIt<RecordLock>().unlock();
    if (mounted) setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightGrayBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.lightTealTint, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline_rounded, size: 34, color: AppColors.teal),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Your health record is locked', style: AppTextStyles.h2, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Use your fingerprint, face or phone PIN to open it. You turned this on in Profile.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(label: 'Unlock', isLoading: _asking, onPressed: _unlock),
            ],
          ),
        ),
      ),
    );
  }
}
