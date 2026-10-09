import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// The day/time picker, built only from the times `/slots/` returned.
///
/// Never a generated grid: the server derives slots from the clinician's
/// recurring availability windows, so any time this widget invented would be
/// one the booking endpoint rejects. An empty [slotsByDay] is the
/// clinician's real answer ("no availability set"), handled by the caller.
class SlotPicker extends StatelessWidget {
  const SlotPicker({
    required this.slotsByDay,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final Map<DateTime, List<DateTime>> slotsByDay;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = slotsByDay.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          Text(_dayLabel(day), style: AppTextStyles.caption.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final slot in slotsByDay[day]!)
                _SlotChip(
                  slot: slot,
                  selected: selected == slot,
                  onTap: () => onSelected(slot),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = day.difference(today).inDays;
    return switch (difference) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => DateFormat('EEEE d MMM').format(day),
    };
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final DateTime slot;
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
          // Padding-sized, deliberately: a Container with `alignment` set and
          // no explicit width expands to its parent's max constraints, which
          // inside a Wrap means the full row — one chip per line instead of a
          // grid of times. The vertical padding is what keeps the 44pt tap
          // target.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Text(
            DateFormat('h:mm a').format(slot),
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.white : AppColors.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
