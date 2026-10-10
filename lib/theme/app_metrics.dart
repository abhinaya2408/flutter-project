import 'package:flutter/widgets.dart';

/// Spacing scale — a port of the `--sp-*` custom properties in
/// `college-bakery/css/style.css` (the 8px system), except where the original
/// CSS uses those tokens.
class AppSpacing {
  AppSpacing._();

  static const double sp1 = 8;
  static const double sp2 = 12;
  static const double sp3 = 16;
  static const double sp4 = 20;
  static const double sp5 = 24;
  static const double sp6 = 32;
  static const double sp7 = 48;
  static const double sp8 = 64;
}

/// Border radii — `--radius-*` in `style.css`.
class AppRadius {
  AppRadius._();

  static const Radius smRadius = Radius.circular(10);
  static const Radius mdRadius = Radius.circular(16);
  static const Radius lgRadius = Radius.circular(24);
  static const Radius pillRadius = Radius.circular(999);

  static const BorderRadius sm = BorderRadius.all(smRadius);
  static const BorderRadius md = BorderRadius.all(mdRadius);
  static const BorderRadius lg = BorderRadius.all(lgRadius);
  static const BorderRadius pill = BorderRadius.all(pillRadius);
}

/// Box shadows — `--shadow-*` in `style.css`
/// (`rgba(43, 35, 32, .08)` → `0x142B2320`, `.10` → `0x1A2B2320`,
/// `.14` → `0x242B2320`).
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x142B2320), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: Color(0x1A2B2320), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: Color(0x242B2320), offset: Offset(0, 16), blurRadius: 40),
  ];
}

/// Border widths used across the original stylesheets
/// (`1.5px` solid borders, `2px` dashed upload area, `1px` hairlines).
class AppBorders {
  AppBorders._();

  static const double hairline = 1;
  static const double regular = 1.5;
  static const double dashed = 2;
}

/// Layout widths — `.container { max-width: 1200px }` and the per-page
/// `max-width` overrides in the original HTML.
class AppLayout {
  AppLayout._();

  static const double container = 1200;
  static const double orderConfirmation = 640;
  static const double notifications = 720;
  static const double ownerOrderDetails = 1100;
  static const double ownerSidebar = 240;

  /// `table.orders-table { min-width: 720px }` on small screens.
  static const double ordersTable = 720;

  /// Card `aspect-ratio` values from the stylesheets.
  static const double cakeImageAspect = 4 / 3;
  static const double heroAspect = 4 / 3.3;

  /// `.navbar` vertical size used by `calc(100vh - 72px)` rules.
  static const double navbarHeight = 72;
}
