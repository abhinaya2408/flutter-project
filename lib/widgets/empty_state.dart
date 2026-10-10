import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// `.empty-state` — dashed border card, 44px emoji, heading, copy and an
/// optional action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sp4,
        vertical: AppSpacing.sp8,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: AppSpacing.sp2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.emptyTitle,
          ),
          const SizedBox(height: AppSpacing.sp1),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.meta.copyWith(fontSize: 14),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sp5),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
