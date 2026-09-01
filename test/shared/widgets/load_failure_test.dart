import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/presentation/garden_screen.dart';
import 'package:furrow/features/habits/presentation/today_screen.dart';
import 'package:furrow/features/stats/presentation/stats_screen.dart';
import 'package:openhearth_design/openhearth_design.dart';

/// A screen whose stream fails shows the fleet failure state: a plain
/// sentence and Try again, never the exception text (C10 checks the source;
/// this checks what actually renders).
void main() {
  const secret = 'SqliteException(5): database is locked';

  for (final (name, screen) in [
    ('Today', const TodayScreen()),
    ('Garden', const GardenScreen()),
    ('Stats', const StatsScreen()),
  ]) {
    testWidgets('$name shows OhErrorState, not the exception', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeHabitsProvider
              .overrideWith((ref) => Stream.error(StateError(secret))),
          allMarksProvider.overrideWith((ref) => const Stream.empty()),
          awardsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(home: Scaffold(body: screen)),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(OhErrorState), findsOneWidget);
      expect(find.text('Couldn’t load your habits'), findsOneWidget);
      expect(find.textContaining('database is locked'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });
  }
}
