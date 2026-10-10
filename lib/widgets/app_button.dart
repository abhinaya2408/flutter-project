import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// Button variants — `.btn-primary`, `.btn-secondary`, `.btn-outline`,
/// `.btn-danger` in `college-bakery/css/style.css`.
enum AppButtonVariant { primary, secondary, outline, danger }

/// A port of `.btn`:
/// `padding: 14px 28px`, pill radius, 15px/600 label, `translateY(-1px)` on
/// hover, `.btn-block` full width, `.btn-sm` `9px 18px` / 13px.
class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.block = false,
    this.small = false,
    this.leading,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool block;
  final bool small;
  final Widget? leading;
  final Widget? trailing;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null;

  Color get _background {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _hovered ? AppColors.coralDark : AppColors.coral;
      case AppButtonVariant.secondary:
        return AppColors.white;
      case AppButtonVariant.outline:
        return _hovered ? AppColors.coralLight : Colors.transparent;
      case AppButtonVariant.danger:
        return _hovered ? AppColors.dangerDark : AppColors.danger;
    }
  }

  Color get _foreground {
    switch (widget.variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        return AppColors.white;
      case AppButtonVariant.secondary:
        return _hovered ? AppColors.coralDark : AppColors.charcoal;
      case AppButtonVariant.outline:
        return AppColors.coralDark;
    }
  }

  Color? get _borderColor {
    switch (widget.variant) {
      case AppButtonVariant.secondary:
        return _hovered ? AppColors.coral : AppColors.border;
      case AppButtonVariant.outline:
        return AppColors.coral;
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        return null;
    }
  }

  List<BoxShadow> get _shadow {
    if (_disabled) return const <BoxShadow>[];
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _hovered ? AppShadows.md : AppShadows.sm;
      case AppButtonVariant.danger:
      case AppButtonVariant.secondary:
      case AppButtonVariant.outline:
        return const <BoxShadow>[];
    }
  }

  EdgeInsets get _padding => widget.small
      ? const EdgeInsets.symmetric(horizontal: 18, vertical: 9)
      : const EdgeInsets.symmetric(horizontal: 28, vertical: 14);

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle =
        widget.small ? AppText.buttonSmall : AppText.button;

    final Widget label = Text(
      widget.label,
      style: baseStyle.copyWith(color: _foreground),
      textAlign: TextAlign.center,
    );

    final Widget content = Row(
      mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.leading != null) ...<Widget>[
          widget.leading!,
          const SizedBox(width: AppSpacing.sp1),
        ],
        Flexible(
          child: DefaultTextStyle.merge(
            child: label,
            style: baseStyle.copyWith(color: _foreground),
          ),
        ),
        if (widget.trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sp1),
          widget.trailing!,
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: !_disabled,
      label: widget.label,
      child: MouseRegion(
        cursor: _disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown:
              _disabled ? null : (_) => setState(() => _pressed = true),
          onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
          onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              0,
              _disabled || _pressed ? 0 : (_hovered ? -1 : 0),
              0,
            ),
            width: widget.block ? double.infinity : null,
            padding: _padding,
            decoration: BoxDecoration(
              color: _background,
              borderRadius: AppRadius.pill,
              border: _borderColor == null
                  ? null
                  : Border.all(
                      color: _borderColor!,
                      width: AppBorders.regular,
                    ),
              boxShadow: _shadow,
            ),
            child: Opacity(
              opacity: _disabled ? 0.5 : 1,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
