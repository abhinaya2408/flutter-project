import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `.demo-banner` — the coral-tinted credentials hint on the sign-in screens.
class DemoBanner extends StatelessWidget {
  const DemoBanner({required this.title, required this.details, super.key});

  final String title;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sp3),
      decoration: BoxDecoration(
        color: AppColors.coralLight,
        borderRadius: AppRadius.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppText.inter(
              size: 13.5,
              weight: FontWeight.w700,
              color: AppColors.coralDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            details,
            style: AppText.inter(
              size: 13.5,
              color: AppColors.coralDark,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
