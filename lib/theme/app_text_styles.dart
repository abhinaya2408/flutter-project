import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography — a port of the type rules in `college-bakery/css/style.css`,
/// `auth.css`, `customize.css`, `student.css` and `owner.css`.
///
/// The original loads Inter (body) + Poppins (display) from Google Fonts, so
/// the Flutter app uses the same two families via the `google_fonts` package.
class AppText {
  AppText._();

  // ---------- Display font (Poppins) ----------
  static TextStyle poppins({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.charcoal,
    double height = 1.2,
  }) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  // ---------- Body font (Inter) ----------
  static TextStyle inter({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double height = 1.55,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  // ---------- Headings ----------
  /// `h1 { font-size: 44px }`
  static TextStyle get h1 => poppins(size: 44);

  /// `@media (max-width: 900px) h1 { font-size: 32px }`
  static TextStyle get h1Mobile => poppins(size: 32);

  /// `.hero h1 { font-size: 52px }`
  static TextStyle get heroTitle => poppins(size: 52);

  /// `@media (max-width: 900px) .hero h1 { font-size: 34px }`
  static TextStyle get heroTitleMobile => poppins(size: 34);

  /// `h2 { font-size: 32px }`
  static TextStyle get h2 => poppins(size: 32);

  /// `h3 { font-size: 22px }`
  static TextStyle get h3 => poppins(size: 22);

  /// `.page-header h1 { font-size: 30px }` (customize page)
  static TextStyle get pageHeader => poppins(size: 30);

  /// `.dashboard-header h1 { font-size: 28px }`
  static TextStyle get dashboardHeader => poppins(size: 28);

  /// `.auth-card h1 { font-size: 26px }`
  static TextStyle get authTitle => poppins(size: 26);

  /// `.owner-topbar h1 { font-size: 26px }`
  static TextStyle get ownerTopbar => poppins(size: 26);

  /// `.brand { font-size: 20px }`
  static TextStyle get brand => poppins(size: 20);

  /// `.section-head` headings reuse `h2`, section sub-labels use the muted
  /// body copy size.
  static TextStyle get sectionSubtitle =>
      inter(size: 16, color: AppColors.textMuted);

  /// Card headings such as `.cake-card-body h3` (17px Poppins 700)
  static TextStyle get cardTitle => poppins(size: 17);

  /// `.form-section h3 { font-size: 17px }`
  static TextStyle get formSectionTitle => poppins(size: 17);

  /// `.detail-card h3 { font-size: 16px }`
  static TextStyle get detailCardTitle => poppins(size: 16);

  /// `.option-card-body h4 { font-size: 15px }`
  static TextStyle get optionCardTitle => poppins(size: 15);

  // ---------- Body copy ----------
  /// `p { color: var(--color-text-muted) }` at the default 16px body size.
  static TextStyle get paragraph => inter(size: 16, color: AppColors.textMuted);

  /// `.hero .lead { font-size: 17px }`
  static TextStyle get heroLead => inter(size: 17, color: AppColors.textMuted);

  /// Default body text colour (`.detail-row` values etc.)
  static TextStyle get body => inter(size: 16, color: AppColors.text);

  /// `.form-group label { font-size: 13.5px; font-weight: 600 }`
  static TextStyle get fieldLabel =>
      inter(size: 13.5, weight: FontWeight.w600, color: AppColors.charcoal);

  /// `input { font-size: 14.5px }`
  static TextStyle get input => inter(size: 14.5, color: AppColors.text);

  /// `.field-error { font-size: 12.5px }`
  static TextStyle get fieldError =>
      inter(size: 12.5, color: AppColors.danger, height: 1.4);

  /// `.btn { font-size: 15px; font-weight: 600 }`
  static TextStyle get button =>
      inter(size: 15, weight: FontWeight.w600, color: AppColors.white);

  /// `.btn-sm { font-size: 13px }`
  static TextStyle get buttonSmall =>
      inter(size: 13, weight: FontWeight.w600, color: AppColors.white);

  /// `.nav-links { font-size: 14.5px; font-weight: 500 }`
  static TextStyle get navLink =>
      inter(size: 14.5, weight: FontWeight.w500, color: AppColors.text);

  /// `.subtitle` / `.section-sub` muted helper copy
  static TextStyle get subtitle => inter(size: 15, color: AppColors.textMuted);

  /// Smaller helper copy: `.option-card-body .desc { font-size: 12.5px }`,
  /// `.order-card .order-meta`, `.notif-time` … (all 12.5px, muted)
  static TextStyle get meta =>
      inter(size: 12.5, color: AppColors.textMuted, height: 1.45);

  /// `.order-card .order-id { font-size: 12.5px; font-weight: 600 }`
  static TextStyle get metaStrong => inter(
        size: 12.5,
        weight: FontWeight.w600,
        color: AppColors.textMuted,
        height: 1.45,
      );

  /// `.detail-row { font-size: 13.5px }`
  static TextStyle get detail =>
      inter(size: 13.5, color: AppColors.text, height: 1.45);

  /// `.detail-row .value { font-weight: 600; color: var(--color-charcoal) }`
  static TextStyle get detailValue => inter(
        size: 13.5,
        weight: FontWeight.w600,
        color: AppColors.charcoal,
        height: 1.45,
      );

  /// `.pill { font-size: 12.5px; font-weight: 600 }`
  static TextStyle get pill =>
      inter(size: 12.5, weight: FontWeight.w600, height: 1.2);

  /// `.toast { font-size: 14px; font-weight: 500 }`
  static TextStyle get toast => inter(
        size: 14,
        weight: FontWeight.w500,
        color: AppColors.white,
        height: 1.4,
      );

  /// `.empty-state h3` uses the 22px display style.
  static TextStyle get emptyTitle => poppins(size: 22);
}
