import 'package:flutter/widgets.dart';

/// Colour palette — a 1:1 port of the `:root` custom properties in
/// `college-bakery/css/style.css` (plus the few literal colours used by
/// `student.css`, `owner.css` and the inline styles in the HTML pages).
class AppColors {
  AppColors._();

  // ---------- Core palette ----------
  static const Color coral = Color(0xFFFF6F61);
  static const Color coralDark = Color(0xFFE85A4F);
  static const Color coralLight = Color(0xFFFFE8E4);
  static const Color cream = Color(0xFFFFFAF6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF2B2320);
  static const Color text = Color(0xFF3D3530);
  static const Color textMuted = Color(0xFF7A6F68);
  static const Color border = Color(0xFFEDE3DD);
  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFD98A1A);
  static const Color danger = Color(0xFFE5484D);

  /// `.btn-danger:hover` — `#c93438`
  static const Color dangerDark = Color(0xFFC93438);

  // ---------- Derived / literal colours ----------
  /// `.navbar` background: `rgba(255, 250, 246, 0.92)`
  static const Color navBackground = Color(0xEBFFFAF6);

  /// `.pill-pending` / `.pill-preparing` background `#FFF1DA`
  static const Color pillPendingBackground = Color(0xFFFFF1DA);

  /// `.pill-accepted` background `#E5F0FF`
  static const Color pillAcceptedBackground = Color(0xFFE5F0FF);

  /// `.pill-accepted` colour `#2563EB`
  static const Color pillAcceptedText = Color(0xFF2563EB);

  /// `.pill-ready` background `#E4F7EA`
  static const Color pillReadyBackground = Color(0xFFE4F7EA);

  /// `.pill-rejected` background `#FDE5E5`
  static const Color pillRejectedBackground = Color(0xFFFDE5E5);

  /// `.notif-item.unread` border `#FFD5CD`
  static const Color notifUnreadBorder = Color(0xFFFFD5CD);

  // ---------- Footer ----------
  static const Color footerText = Color(0xFFDCD3CD);
  static const Color footerLink = Color(0xFFB8ADA6);
  static const Color footerBottom = Color(0xFF948B85);
  static const Color footerDivider = Color(0x1AFFFFFF);
}
