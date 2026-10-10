import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Global [ThemeData] mirroring the `body`, heading and form-control rules of
/// `college-bakery/css/style.css` + `auth.css`.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final ThemeData base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.coral,
        onPrimary: AppColors.white,
        secondary: AppColors.coralDark,
        surface: AppColors.white,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
      // `:focus-visible { outline: 3px solid var(--color-coral) }`
      focusColor: AppColors.coral,
      splashFactory: InkRipple.splashFactory,
      textTheme: base.textTheme.copyWith(
        displayLarge: AppText.h1,
        displayMedium: AppText.h2,
        displaySmall: AppText.h3,
        headlineMedium: AppText.h2,
        titleLarge: AppText.h3,
        bodyLarge: AppText.body,
        bodyMedium: AppText.paragraph,
        labelLarge: AppText.button,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      // The original `select { background: var(--color-cream) }`
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColors.text),
      ),
      // `input { background: var(--color-cream) }` — the shared field styling
      // lives in `AppTextField`, these keep third-party pickers consistent.
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.white,
        headerBackgroundColor: AppColors.coral,
        headerForegroundColor: AppColors.white,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.white,
        dialBackgroundColor: AppColors.cream,
        hourMinuteColor: AppColors.coralLight,
        hourMinuteTextColor: AppColors.coralDark,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.coral,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
    );
  }
}
