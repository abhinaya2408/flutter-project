import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `.section-head` — heading + copy on the left, an optional action on the
/// right, aligned to the baseline and wrapping on narrow screens.
class SectionHead extends StatelessWidget {
  const SectionHead({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: AppText.h2),
        const SizedBox(height: AppSpacing.sp2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(subtitle, style: AppText.sectionSubtitle),
        ),
      ],
    );

    if (trailing == null) return heading;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: AppSpacing.sp3),
              trailing!,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.sp3),
            trailing!,
          ],
        );
      },
    );
  }
}
