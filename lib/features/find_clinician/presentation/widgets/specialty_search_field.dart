import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// The search field on Find a Clinician.
///
/// Labelled "specialty", not "doctors, specialists…", because
/// `?specialty=` is the only text filter this backend has — it matches the
/// specialty field with `icontains` and nothing else. A box that invites a
/// doctor's name and then returns nothing would read as a broken search.
///
/// Debounces here rather than in the Bloc: one keystroke should not be one
/// request, and the Bloc discards out-of-order responses anyway.
class SpecialtySearchField extends StatefulWidget {
  const SpecialtySearchField({
    required this.initialValue,
    required this.onChanged,
    super.key,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<SpecialtySearchField> createState() => _SpecialtySearchFieldState();
}

class _SpecialtySearchFieldState extends State<SpecialtySearchField> {
  static const _debounce = Duration(milliseconds: 350);

  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void didUpdateWidget(SpecialtySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the field in step when the filter is cleared from elsewhere on
    // the page (the "Clear filters" action, a specialty chip) without
    // fighting the user mid-type.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => widget.onChanged(value));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        _timer?.cancel();
        widget.onChanged(value);
      },
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Search by specialty',
        hintStyle: AppTextStyles.bodyMuted,
        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.muted),
                tooltip: 'Clear search',
                onPressed: () {
                  _timer?.cancel();
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: AppColors.lightGrayBg,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
