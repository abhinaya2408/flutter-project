import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/breakpoints.dart';
import 'page_container.dart';

/// One entry in `.nav-links`.
class NavEntry {
  const NavEntry({
    required this.label,
    required this.onTap,
    this.active = false,
    this.badgeCount,
    this.collapseOnTapLabel,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  /// Unread notification count rendered as `.nav-badge` (hidden when zero).
  final int? badgeCount;

  /// Menu label used inside the collapsed menu (defaults to [label]).
  final String? collapseOnTapLabel;
}

/// `.navbar` — sticky, translucent cream background with a blur, bottom border
/// and (under 640px) the hamburger toggle with the collapsed menu panel.
class AppNavBar extends StatefulWidget {
  const AppNavBar({
    required this.brandLabel,
    required this.onBrandTap,
    required this.entries,
    this.brandSuffix,
    this.brandMark = '🍰',
    this.brandMarkColor = AppColors.coral,
    super.key,
  });

  final String brandLabel;
  final VoidCallback onBrandTap;
  final List<NavEntry> entries;

  /// The `Bakery Portal` tag shown next to the brand on the bakery screens.
  final String? brandSuffix;

  final String brandMark;

  /// The brand mark is coral on the student/landing nav and white on the
  /// bakery nav (`owner.css` uses the same mark).
  final Color brandMarkColor;

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool collapsed = constraints.maxWidth <= Breakpoints.nav;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.navBackground,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: PageContainer(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppLayout.navbarHeight,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          InkWell(
                            onTap: widget.onBrandTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: widget.brandMarkColor,
                                      borderRadius: AppRadius.sm,
                                    ),
                                    child: Text(
                                      widget.brandMark,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sp1),
                                  Text(
                                    widget.brandLabel,
                                    style: AppText.brand,
                                  ),
                                  if (widget.brandSuffix != null) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.brandSuffix!,
                                      style: AppText.inter(
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (collapsed)
                            _NavToggle(
                              open: _menuOpen,
                              onTap: () =>
                                  setState(() => _menuOpen = !_menuOpen),
                            )
                          else
                            // `Flexible` + a horizontal scroll keeps the links on
                            // one line like `.nav-links`, without clipping them
                            // when the labels are wider than the bar.
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: <Widget>[
                                    for (final NavEntry entry in widget.entries)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: AppSpacing.sp5,
                                        ),
                                        child: _NavLink(entry: entry),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (collapsed && _menuOpen)
              Container(
                width: double.infinity,
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sp5,
                  vertical: AppSpacing.sp4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < widget.entries.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: AppSpacing.sp3),
                      _NavLink(
                        entry: widget.entries[i],
                        onTapOverride: () {
                          setState(() => _menuOpen = false);
                          widget.entries[i].onTap();
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.entry, this.onTapOverride});

  final NavEntry entry;
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapOverride ?? entry.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            entry.label,
            style: AppText.navLink.copyWith(
              color: entry.active ? AppColors.coralDark : AppColors.text,
            ),
          ),
          if (entry.badgeCount != null && entry.badgeCount! > 0) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: AppRadius.pill,
              ),
              child: Text(
                '${entry.badgeCount}',
                style: AppText.inter(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.white,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavToggle extends StatelessWidget {
  const _NavToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sp1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i < 2 ? 5 : 0),
                child: Container(
                  width: 22,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

