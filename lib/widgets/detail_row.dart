import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `.detail-row` — muted label on the left, bold value on the right, with a
/// hairline divider between rows (`:last-child` has none).
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.isLast = false,
    super.key,
  });

  final String label;
  final String? value;

  /// Used where the original renders markup instead of text (the status pill).
  final Widget? valueWidget;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp2),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppText.detail.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.sp3),
          valueWidget != null
              ? valueWidget!
              : Flexible(
                  child: Text(
                    value ?? '',
                    textAlign: TextAlign.right,
                    style: AppText.detailValue,
                  ),
                ),
        ],
      ),
    );
  }
}
