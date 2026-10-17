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
///
/// Day first, then time — one day's slots at a time, so a later day is one
/// tap away instead of a scroll past every earlier day's times (see
/// docs/ui_research/phase3_design_system.md).
class SlotPicker extends StatefulWidget {
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
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  /// The day being browsed — view state only. The booking itself only ever
  /// carries [SlotPicker.selected].
  DateTime? _browsing;

  DateTime _activeDay(List<DateTime> days) {
    if (_browsing != null && widget.slotsByDay.containsKey(_browsing)) {
      return _browsing!;
    }
    final selected = widget.selected;
    if (selected != null) {
      final day = _dayOf(selected);
      if (widget.slotsByDay.containsKey(day)) return day;
    }
    return days.first;
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.slotsByDay.keys.toList()..sort();
    final active = _activeDay(days);
    final slots = [...widget.slotsByDay[active]!]..sort();
    final selected = widget.selected;
    final selectedDay = selected == null ? null : _dayOf(selected);

    final byPeriod = <_Period, List<DateTime>>{};
    for (final slot in slots) {
      byPeriod.putIfAbsent(_Period.of(slot), () => []).add(slot);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final day = days[index];
              return _DayCard(
                day: day,
                slotCount: widget.slotsByDay[day]!.length,
                isActive: day == active,
                holdsSelection: day == selectedDay,
                onTap: () => setState(() => _browsing = day),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(_longDayLabel(active), style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.md),
        for (final period in _Period.values)
          if (byPeriod[period] case final periodSlots?) ...[
            Text(
              period.label,
              style:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SlotGrid(
              slots: periodSlots,
              selected: selected,
              onSelected: widget.onSelected,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
      ],
    );
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static String _longDayLabel(DateTime day) {
    final full = DateFormat('EEEE d MMMM').format(day);
    return switch (_daysFromToday(day)) {
      0 => 'Today · $full',
      1 => 'Tomorrow · $full',
      _ => full,
    };
  }
}

int _daysFromToday(DateTime day) {
  final now = DateTime.now();
  return day.difference(DateTime(now.year, now.month, now.day)).inDays;
}

enum _Period {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  const _Period(this.label);

  final String label;

  static _Period of(DateTime t) => t.hour < 12
      ? morning
      : t.hour < 17
          ? afternoon
          : evening;
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.slotCount,
    required this.isActive,
    required this.holdsSelection,
    required this.onTap,
  });

  final DateTime day;
  final int slotCount;
  final bool isActive;

  /// The patient's chosen time is on this day — marked so it stays findable
  /// while they browse other days.
  final bool holdsSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekday =
        _daysFromToday(day) == 0 ? 'Today' : DateFormat('EEE').format(day);
    final foreground = isActive ? AppColors.white : AppColors.ink;
    final secondary = isActive ? AppColors.white70 : AppColors.muted;

    return Semantics(
      selected: isActive,
      button: true,
      label: '${DateFormat('EEEE d MMMM').format(day)}, '
          '$slotCount ${slotCount == 1 ? 'time' : 'times'} available',
      excludeSemantics: true,
      child: Material(
        color: isActive ? AppColors.teal : AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(weekday,
                    style: AppTextStyles.caption.copyWith(color: secondary)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d').format(day),
                  style:
                      AppTextStyles.h1.copyWith(color: foreground, height: 1.1),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: holdsSelection
                        ? (isActive ? AppColors.white : AppColors.teal)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three equal columns, so times line up instead of wrapping into a ragged
/// row where "9:00 AM" and "10:00 AM" are different widths.
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final List<DateTime> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  static const _columns = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - AppSpacing.sm * (_columns - 1)) / _columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final slot in slots)
              SizedBox(
                width: width,
                child: _SlotChip(
                  slot: slot,
                  selected: selected == slot,
                  onTap: () => onSelected(slot),
                ),
              ),
          ],
        );
      },
    );
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
          height: AppSpacing.touchTarget,
          alignment: Alignment.center,
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
