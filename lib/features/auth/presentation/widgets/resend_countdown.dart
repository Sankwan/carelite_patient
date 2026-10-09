import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// "Didn't get a code? Resend in 00:45", counting down to a live Resend
/// action. Without this a user whose SMS never arrives has no way forward
/// — the Figma frame shows the timer but the built screen had neither.
class ResendCountdown extends StatefulWidget {
  const ResendCountdown({
    required this.onResend,
    this.duration = const Duration(seconds: 45),
    super.key,
  });

  final VoidCallback onResend;
  final Duration duration;

  @override
  State<ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<ResendCountdown> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _secondsLeft = widget.duration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _handleResend() {
    widget.onResend();
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0;
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        const Text("Didn't get a code? ", style: AppTextStyles.bodyMuted),
        if (canResend)
          TextButton(
            onPressed: _handleResend,
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Resend',
              style: AppTextStyles.body.copyWith(
                color: AppColors.tealText,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            'Resend in $minutes:$seconds',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}
