import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../utils/breakpoints.dart';

/// `.container` — centered `max-width: 1200px` with `0 var(--sp-5)` padding
/// (`var(--sp-3)` under 640px). Pages that override the max width in their HTML
/// pass it through [maxWidth].
class PageContainer extends StatelessWidget {
  const PageContainer({
    required this.child,
    this.maxWidth = AppLayout.container,
    this.padding = true,
    this.top = 0,
    this.bottom = 0,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool padding;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double sidePadding =
            padding ? Breakpoints.containerPadding(constraints.maxWidth) : 0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.only(
                left: sidePadding,
                right: sidePadding,
                top: top,
                bottom: bottom,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
