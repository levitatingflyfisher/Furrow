import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/data/focus_override_store.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';

// Franklin's actual method: ONE virtue per week gets the attention. The
// rotation supplies a default; the household can point the week somewhere
// else. The override is per-week (next Monday the rotation resumes) and
// lives in the userPrefs KV table.
void main() {
  group('focusVirtueForWeek', () {
    final anchor = DateTime(2026, 1, 1);

    test('no override → the deterministic rotation', () {
      final rotation = virtueOfWeek(anchor, DateTime(2026, 7, 27));
      final focus = focusVirtueForWeek(
          anchorMonday: anchor, now: DateTime(2026, 7, 27));
      expect(focus.key, rotation.key);
    });

    test('an override wins for its week', () {
      final focus = focusVirtueForWeek(
        anchorMonday: anchor,
        now: DateTime(2026, 7, 27),
        overrideKey: 'humility',
      );
      expect(focus.key, 'humility');
    });

    test('an unknown override key falls back to the rotation, not a crash',
        () {
      final rotation = virtueOfWeek(anchor, DateTime(2026, 7, 27));
      final focus = focusVirtueForWeek(
        anchorMonday: anchor,
        now: DateTime(2026, 7, 27),
        overrideKey: 'not-a-virtue',
      );
      expect(focus.key, rotation.key);
    });
  });

  group('FocusOverrideStore', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('round-trips a weekly override and scopes it to that week', () async {
      final store = FocusOverrideStore(db);
      final thisMonday = DateTime(2026, 7, 27);
      final nextMonday = DateTime(2026, 8, 3);

      expect(await store.overrideFor(thisMonday), isNull);
      await store.setOverride(thisMonday, 'order');
      expect(await store.overrideFor(thisMonday), 'order');
      expect(await store.overrideFor(nextMonday), isNull,
          reason: 'the rotation resumes next week — overrides never leak');

      await store.clearOverride(thisMonday);
      expect(await store.overrideFor(thisMonday), isNull);
    });
  });
}
