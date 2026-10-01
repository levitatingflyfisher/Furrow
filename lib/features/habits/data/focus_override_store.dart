import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/domain/franklin_virtues.dart';
import 'package:furrow/shared/extensions/datetime_ext.dart';

/// Per-week focus-virtue overrides, keyed by the week's Monday in the
/// userPrefs KV table (`focus_virtue_2026-07-27`). Written only from the
/// Today surface — never before onboarding, whose "prefs table empty"
/// sentinel must stay meaningful.
class FocusOverrideStore {
  FocusOverrideStore(this._db);

  final AppDatabase _db;

  String _key(DateTime weekMonday) =>
      'focus_virtue_${weekMonday.startOfWeek.toDateDay()}';

  Future<String?> overrideFor(DateTime weekMonday) async {
    final row = await (_db.select(_db.userPrefs)
          ..where((p) => p.key.equals(_key(weekMonday))))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setOverride(DateTime weekMonday, String virtueKey) =>
      _db.into(_db.userPrefs).insertOnConflictUpdate(
          UserPrefsCompanion.insert(key: _key(weekMonday), value: virtueKey));

  Future<void> clearOverride(DateTime weekMonday) async {
    await (_db.delete(_db.userPrefs)
          ..where((p) => p.key.equals(_key(weekMonday))))
        .go();
  }
}

/// The focus virtue for the week holding [today]: the household's override
/// when set, else the rotation anchored on the year's first Monday week.
Future<Virtue> focusVirtueOn(AppDatabase db, DateTime today) async {
  final overrideKey = await FocusOverrideStore(db).overrideFor(today.startOfWeek);
  final anchor = DateTime(today.year, 1, 1).startOfWeek;
  return focusVirtueForWeek(
      anchorMonday: anchor, now: today, overrideKey: overrideKey);
}
