import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/router/app_shell.dart';
import 'package:furrow/core/storage/app_database.dart';

/// Audit finding 4: the earn reveal was a four-second snackbar carrying
/// only `awards.first`'s fact line, so a second award earned by the same
/// write was never named and a phone in a pocket missed it all. The reveal
/// now names every award and stays until it is dismissed.
void main() {
  testWidgets('every award earned by a write is named, and it stays',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/today', builder: (_, __) => const SizedBox()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();

    // Banner exits and entrances are 250 ms animations: give them frames.
    Future<void> settleBanner() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    final container =
        ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    container.read(newlyEarnedAwardsProvider.notifier).state = const [
      HabitBadge(id: 'first_mark', kind: 'firstMark', threshold: 1, earnedAt: 1),
      HabitBadge(id: 'chain_7', kind: 'chain', threshold: 7, earnedAt: 1),
    ];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('First Light'), findsOneWidget);
    expect(find.textContaining('Seven'), findsOneWidget);

    // No four-second timeout.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('First Light'), findsOneWidget,
        reason: 'the reveal stays until dismissed');

    // A second write earns another award while the first reveal is up: the
    // first is not swept away unread; the second waits its turn.
    container.read(newlyEarnedAwardsProvider.notifier).state = const [
      HabitBadge(id: 'chain_30', kind: 'chain', threshold: 30, earnedAt: 2),
    ];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('First Light'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await settleBanner();
    expect(find.textContaining('First Light'), findsNothing);
    expect(find.textContaining('Whetted'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await settleBanner();
    expect(find.textContaining('Whetted'), findsNothing);

    await db.close();
    // Let the shell's 5 s award-state reset run out.
    await tester.pump(const Duration(seconds: 6));
  });
}
