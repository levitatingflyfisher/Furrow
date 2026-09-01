import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/shared/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';

/// Tier-T lock: Furrow's TextTheme is the shared habit-lineage ladder
/// (openhearth_design's OhTypography.materialTextTheme), role for role. It is
/// compared against the package, not against literals, so the next ladder
/// move in ohStyle carries through instead of breaking this test; what it
/// catches is Furrow drifting from the fleet by overriding a role locally.
///
/// It also pins that both themes carry the fleet colour roles, since Furrow
/// builds its own ThemeData and OhTheme is not there to attach them.
void main() {
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
    final expected = roles(OhTypography.materialTextTheme);
    final actual = roles(theme.textTheme);
    expected.forEach((role, want) {
      final got = actual[role];
      expect(got, isNotNull, reason: '$themeName $role');
      expect(got!.fontFamily, want!.fontFamily,
          reason: '$themeName $role family');
      expect(got.fontSize, want.fontSize, reason: '$themeName $role size');
      expect(got.fontWeight, want.fontWeight,
          reason: '$themeName $role weight');
    });
  }

  test('body text is on the 0.7.0 ladder (16, not the old 14)', () {
    expect(AppTheme.light.textTheme.bodyMedium!.fontSize, 16);
  });

  test('light theme text ladder is the shared ladder', () {
    check('light', AppTheme.light);
  });

  test('dark theme text ladder is the shared ladder', () {
    check('dark', AppTheme.dark);
  });

  test('both themes attach the fleet colour roles for their brightness', () {
    expect(AppTheme.light.extension<OhColorRoles>(), OhColorRoles.light);
    expect(AppTheme.dark.extension<OhColorRoles>(), OhColorRoles.hearthDark);
  });
}
