import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// The six boxed digits from Figma node 208:1274.
///
/// One real [TextField] sits invisibly behind six painted boxes rather than
/// six separate fields: it keeps paste, SMS autofill and backspace working
/// the way the platform already does, none of which survives a six-field
/// implementation with manual focus juggling.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    required this.controller,
    required this.onCompleted,
    this.length = 6,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final int length;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Semantics(
      textField: true,
      label: 'Verification code, ${widget.length} digits',
      value: code.isEmpty ? 'empty' : code.split('').join(' '),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final hasDigit = index < code.length;
              final isNext = index == code.length && _focusNode.hasFocus;
              return Container(
                height: 56,
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasDigit ? AppColors.white : AppColors.lightGrayBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: hasDigit || isNext ? AppColors.teal : AppColors.border,
                    width: hasDigit || isNext ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  hasDigit ? code[index] : '',
                  style: AppTextStyles.h1,
                ),
              );
            }),
          ),
          // The real input: transparent and stretched over the boxes so a
          // tap anywhere on the row focuses it.
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              showCursor: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      ),
    );
  }
}
