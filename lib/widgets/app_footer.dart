import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/breakpoints.dart';
import 'page_container.dart';

/// `.site-footer` — charcoal background, three columns and the copyright bar.
class AppFooter extends StatelessWidget {
  const AppFooter({
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onPopularCakes,
    required this.onBakeryLogin,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onPopularCakes;
  final VoidCallback onBakeryLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.charcoal,
      padding: const EdgeInsets.only(
        top: AppSpacing.sp7,
        bottom: AppSpacing.sp5,
      ),
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final Widget brand = _FooterBrand();
                final Widget students = _FooterColumn(
                  title: 'For Students',
                  links: <_FooterLink>[
                    _FooterLink('Sign In', onSignIn),
                    _FooterLink('Create Account', onCreateAccount),
                    _FooterLink('Popular Cakes', onPopularCakes),
                  ],
                );
                final Widget staff = _FooterColumn(
                  title: 'For Bakery Staff',
                  links: <_FooterLink>[
                    _FooterLink('Bakery Member Login', onBakeryLogin),
                  ],
                );

                if (width <= Breakpoints.nav) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      brand,
                      const SizedBox(height: AppSpacing.sp6),
                      students,
                      const SizedBox(height: AppSpacing.sp6),
                      staff,
                    ],
                  );
                }

                final double brandFlex = width <= Breakpoints.wide ? 1 : 2;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: brandFlex.toInt(), child: brand),
                    const SizedBox(width: AppSpacing.sp6),
                    Expanded(child: students),
                    const SizedBox(width: AppSpacing.sp6),
                    Expanded(child: staff),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sp6),
            Container(
              padding: const EdgeInsets.only(top: AppSpacing.sp4),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.footerDivider),
                ),
              ),
              child: Center(
                child: Text(
                  '© 2026 Crumb & Cream. Frontend demo prototype — built with HTML, CSS & JavaScript.',
                  textAlign: TextAlign.center,
                  style: AppText.inter(
                    size: 13,
                    color: AppColors.footerBottom,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '🍰 Crumb & Cream',
          style: AppText.poppins(size: 15, color: AppColors.white),
        ),
        const SizedBox(height: AppSpacing.sp3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'Your college bakery for custom, made-to-order cakes. Demo frontend prototype — no real orders are processed.',
            style: AppText.inter(size: 14, color: AppColors.footerLink),
          ),
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppText.poppins(size: 15, color: AppColors.white),
        ),
        const SizedBox(height: AppSpacing.sp3),
        for (int i = 0; i < links.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sp2),
          InkWell(
            onTap: links[i].onTap,
            child: Text(
              links[i].label,
              style: AppText.inter(size: 14, color: AppColors.footerLink),
            ),
          ),
        ],
      ],
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}
