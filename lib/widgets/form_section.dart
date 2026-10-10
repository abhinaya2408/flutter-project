import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `.form-section` — the white card that wraps each block of the customize
/// form, with the 17px heading, the coral `Required` tag and the optional
/// `.section-sub` helper line.
class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.child,
    this.isRequired = false,
    this.subtitle,
    super.key,
  });

  final String title;
  final Widget child;
  final bool isRequired;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(child: Text(title, style: AppText.formSectionTitle)),
              if (isRequired) ...<Widget>[
                const SizedBox(width: AppSpacing.sp2),
                Text(
                  'Required',
                  style: AppText.inter(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.coralDark,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sp1,
                bottom: AppSpacing.sp3,
              ),
              child: Text(
                subtitle!,
                style: AppText.meta.copyWith(fontSize: 13.5),
              ),
            )
          else
            const SizedBox(height: AppSpacing.sp4),
          child,
        ],
      ),
    );
  }
}
