import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../utils/breakpoints.dart';

/// A grid that switches column counts at exactly the same widths as
/// `grid-template-columns` in the original stylesheets.
///
/// Rows are laid out manually (Expanded + IntrinsicHeight) instead of using a
/// [GridView] so cards keep their natural height — exactly like CSS grid, where
/// cards in a row stretch to the tallest item.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    required this.desktopColumns,
    this.tabletColumns,
    this.mobileColumns = 1,
    this.tabletBreakpoint = Breakpoints.wide,
    this.mobileBreakpoint = Breakpoints.nav,
    this.gap = AppSpacing.sp3,
    this.equalRowHeights = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final List<Widget> children;
  final int desktopColumns;

  /// Column count under [tabletBreakpoint] (defaults to [desktopColumns]).
  final int? tabletColumns;

  /// Column count under [mobileBreakpoint].
  final int mobileColumns;

  final double tabletBreakpoint;
  final double mobileBreakpoint;
  final double gap;
  final bool equalRowHeights;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns;
        if (width <= mobileBreakpoint) {
          columns = mobileColumns;
        } else if (width <= tabletBreakpoint) {
          columns = tabletColumns ?? desktopColumns;
        } else {
          columns = desktopColumns;
        }
        return _buildRows(columns);
      },
    );
  }

  Widget _buildRows(int columns) {
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < children.length; start += columns) {
      final List<Widget> rowChildren = <Widget>[];
      for (int i = 0; i < columns; i++) {
        final int index = start + i;
        if (i > 0) rowChildren.add(SizedBox(width: gap));
        if (index < children.length) {
          rowChildren.add(Expanded(child: children[index]));
        } else {
          // Keep the last row aligned with the grid columns.
          rowChildren.add(const Expanded(child: SizedBox()));
        }
      }

      Widget row = Row(
        crossAxisAlignment:
            equalRowHeights ? CrossAxisAlignment.stretch : crossAxisAlignment,
        children: rowChildren,
      );
      if (equalRowHeights) row = IntrinsicHeight(child: row);

      rows.add(row);
      if (start + columns < children.length) {
        rows.add(SizedBox(height: gap));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Two-column form row (`.form-row`) that collapses to one column under 520px.
class FormRow extends StatelessWidget {
  const FormRow({
    required this.first,
    required this.second,
    this.gap = AppSpacing.sp3,
    super.key,
  });

  final Widget first;
  final Widget second;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth <= Breakpoints.auth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              first,
              SizedBox(height: gap),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: first),
            SizedBox(width: gap),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
