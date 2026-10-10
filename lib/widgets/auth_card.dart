import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/breakpoints.dart';

/// `.auth-page` + `.auth-card` — the centered card used by the three sign-in /
/// registration screens (`max-width: 440px`, `560px` for the `.wide` variant).
class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
    this.backLabel,
    this.onBack,
    this.footer,
    this.wide = false,
    super.key,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? backLabel;
  final VoidCallback? onBack;
  final Widget? footer;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool compact = width <= Breakpoints.auth;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sp4 : AppSpacing.sp6,
            vertical: AppSpacing.sp6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 560 : 440),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.sp4 : AppSpacing.sp6,
                  vertical: compact ? AppSpacing.sp5 : AppSpacing.sp7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (backLabel != null)
                      InkWell(
                        onTap: onBack,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sp4,
                          ),
                          child: Text(
                            backLabel!,
                            style: AppText.inter(
                              size: 13.5,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
                      decoration: BoxDecoration(
                        color: AppColors.coralLight,
                        borderRadius: AppRadius.sm,
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                    Text(title, style: AppText.authTitle),
                    if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AppText.subtitle.copyWith(fontSize: 16),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sp5),
                    ...children,
                    if (footer != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sp5),
                      Center(child: footer!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `.auth-footer-link` — "New to the bakery? Create an account"
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    required this.leadingText,
    required this.linkText,
    required this.onTap,
    super.key,
  });

  final String leadingText;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          leadingText,
          style: AppText.inter(size: 14, color: AppColors.textMuted),
        ),
        InkWell(
          onTap: onTap,
          child: Text(
            linkText,
            style: AppText.inter(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.coralDark,
            ),
          ),
        ),
      ],
    );
  }
}
