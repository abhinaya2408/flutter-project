import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `.form-group` — label above the control, `.field-error` below it.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.autofillHints,
    this.readOnly = false,
    this.onTap,
    this.trailingIcon,
    this.placeholder,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? trailingIcon;
  final String? placeholder;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.label, style: AppText.fieldLabel),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          autofillHints: widget.autofillHints,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          style: AppText.input,
          cursorColor: AppColors.coral,
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            hintText: widget.hint ?? widget.placeholder,
            hintStyle: AppText.input.copyWith(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            filled: true,
            fillColor: _focused ? AppColors.white : AppColors.cream,
            suffixIcon: widget.trailingIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.sm,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.border,
                width: AppBorders.regular,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.sm,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.coral,
                width: AppBorders.regular,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(widget.error!, style: AppText.fieldError),
          ),
      ],
    );
  }
}

/// The `.form-section textarea` variant (`rows="3"`).
class AppTextArea extends StatefulWidget {
  const AppTextArea({
    required this.controller,
    this.hint,
    this.onChanged,
    this.minLines = 3,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final int minLines;

  @override
  State<AppTextArea> createState() => _AppTextAreaState();
}

class _AppTextAreaState extends State<AppTextArea> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      minLines: widget.minLines,
      maxLines: widget.minLines,
      style: AppText.input,
      cursorColor: AppColors.coral,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: AppText.input.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        filled: true,
        fillColor: _focused ? AppColors.white : AppColors.cream,
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(
            color: AppColors.border,
            width: AppBorders.regular,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(
            color: AppColors.coral,
            width: AppBorders.regular,
          ),
        ),
      ),
    );
  }
}

/// A non-editable field that opens the platform picker — the Flutter
/// equivalent of `<input type="date">` / `<input type="time">`, keeping the
/// same label + `.field-error` structure.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
    this.icon,
    this.placeholder,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? error;
  final IconData? icon;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final bool hasError = error != null && error!.isNotEmpty;
    final bool hasValue = value.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppText.fieldLabel),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: AppRadius.sm,
              border: Border.all(
                color: hasError ? AppColors.danger : AppColors.border,
                width: AppBorders.regular,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    hasValue ? value : (placeholder ?? ''),
                    style: AppText.input.copyWith(
                      color: hasValue
                          ? AppColors.text
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(icon, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: AppText.fieldError),
          ),
      ],
    );
  }
}

/// `.field-error` used on its own (the customize form error, the image error).
class FieldErrorText extends StatelessWidget {
  const FieldErrorText({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(message!, style: AppText.fieldError),
    );
  }
}
