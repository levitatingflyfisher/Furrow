import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Fonts come from openhearth_design's package fonts (0.7.2+) and are
  // referenced by family — not fetched from fonts.gstatic.com at runtime.
  // This keeps the app fully local-first: no font egress on first launch.
  // See app_text_styles.dart and test/shared/theme/offline_fonts_test.dart.
  //
  // The ladder itself is the shared habit-lineage Material scale from
  // openhearth_design (0.7.0 moved it onto the fleet type ladder: body text
  // is 16, not 14). text_theme_identity_test.dart pins Furrow to it.
  static const TextTheme _textTheme = OhTypography.materialTextTheme;

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.furrow500,
      brightness: Brightness.light,
      surface: AppColors.linen100,
      onSurface: AppColors.linen900,
    ),
    scaffoldBackgroundColor: AppColors.linen100,
    shadowColor: AppColors.linen900.withValues(alpha: 0.15),
    textTheme: _textTheme,
    // Furrow builds its own ThemeData, so OhTheme is not there to attach
    // the fleet colour roles (warmth vs urgency, secondary text). Attach
    // them here so OhColorRoles.of and the shared widgets see Furrow's
    // brightness rather than a fallback.
    extensions: const [OhColorRoles.light],
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.linen200,
      shadowColor: AppColors.linen900.withValues(alpha: 0.1),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.furrow500,
      brightness: Brightness.dark,
      surface: AppColors.warmDark,
    ),
    scaffoldBackgroundColor: AppColors.warmDark,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    textTheme: _textTheme,
    extensions: const [OhColorRoles.hearthDark],
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.warmDark2,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
