import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/shared/theme/app_theme.dart';

/// Tier-T lock: Furrow's TextTheme must stay byte-equal to the hand-rolled
/// Lora/Nunito Material ladder it shipped with (now provided by
/// openhearth_design's OhTypography.materialTextTheme). Every triple below
/// is the OLD const block's literal value — if the shared package ever
/// drifts, this fails before any golden does.
void main() {
  // role → (family, size, weight)
  const expected = <String, (String, double, FontWeight?)>{
    'displayLarge': ('Lora', 57, FontWeight.w700),
    'displayMedium': ('Lora', 45, FontWeight.w700),
    'displaySmall': ('Lora', 36, FontWeight.w700),
    'headlineLarge': ('Lora', 32, FontWeight.w700),
    'headlineMedium': ('Lora', 28, FontWeight.w600),
    'headlineSmall': ('Lora', 24, FontWeight.w600),
    'titleLarge': ('Nunito', 22, FontWeight.w700),
    'titleMedium': ('Nunito', 16, FontWeight.w600),
    'titleSmall': ('Nunito', 14, FontWeight.w600),
    'bodyLarge': ('Nunito', 16, null),
    'bodyMedium': ('Nunito', 14, null),
    'bodySmall': ('Nunito', 12, null),
    'labelLarge': ('Nunito', 14, FontWeight.w600),
    'labelMedium': ('Nunito', 12, FontWeight.w500),
    'labelSmall': ('Nunito', 11, FontWeight.w500),
  };

  Map<String, TextStyle?> roles(TextTheme t) => {
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };

  void check(String themeName, ThemeData theme) {
    final actual = roles(theme.textTheme);
    expected.forEach((role, spec) {
      final (family, size, weight) = spec;
      final style = actual[role];
      expect(style, isNotNull, reason: '$themeName $role');
      expect(style!.fontFamily, family, reason: '$themeName $role family');
      expect(style.fontSize, size, reason: '$themeName $role size');
      if (weight != null) {
        expect(style.fontWeight, weight, reason: '$themeName $role weight');
      }
    });
  }

  test('light theme text ladder matches the original hand-rolled block', () {
    check('light', AppTheme.light);
  });

  test('dark theme text ladder matches the original hand-rolled block', () {
    check('dark', AppTheme.dark);
  });
}
