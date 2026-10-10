/// Responsive breakpoints taken from the media queries in the original
/// stylesheets.
///
/// The Flutter layouts switch at exactly the same widths so a phone/tablet
/// renders the same arrangement the web app renders at that width.
class Breakpoints {
  Breakpoints._();

  /// `style.css @media (max-width: 900px)` — h1 scaling, hero stacking,
  /// 2-column card grids, `student.css` stat/detail grids.
  static const double wide = 900;

  /// `customize.css @media (max-width: 980px)` and
  /// `owner.css @media (max-width: 980px)` — stacked customize layout,
  /// collapsed owner sidebar, scrollable orders table.
  static const double desktop = 980;

  /// `style.css @media (max-width: 640px)` — hamburger nav, single column
  /// grids, tighter container padding.
  static const double nav = 640;

  /// `student.css @media (max-width: 560px)` — 2-column stat grid.
  static const double compact = 560;

  /// `auth.css @media (max-width: 520px)` — auth card padding, single-column
  /// form rows.
  static const double auth = 520;

  /// `.container` padding: `var(--sp-5)` normally, `var(--sp-3)` under 640px.
  static double containerPadding(double width) =>
      width <= nav ? 16 : 24;

  /// The largest allowed content width for a page.
  static double contentWidth(double width, double maxWidth) =>
      width > maxWidth ? maxWidth : width;
}
