import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/onboarding/presentation/onboarding_screen.dart';

/// The router sends a device with an empty UserPrefs table to onboarding.
/// Onboarding used to leave a row behind by writing a weekStart preference
/// that nothing read (furrow:mind-in-mind-15); with that preference gone,
/// finishing onboarding must write an explicit marker, or every new user
/// would loop back into it.
void main() {
  testWidgets('finishing onboarding leaves the onboarded marker',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
            path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/today', builder: (_, __) => const Text('TODAY')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A blank field'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    final rows = (await tester.runAsync(() => db.select(db.userPrefs).get()))!;
    expect({for (final r in rows) r.key: r.value}, {'onboarded': 'true'});
    expect(find.text('TODAY'), findsOneWidget);
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });
}
