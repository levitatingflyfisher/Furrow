import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:furrow/features/settings/data/local_settings_repository.dart';
import 'package:openhearth_design/openhearth_design.dart';

/// Theme is light, dark or follow the phone, default follow the phone
/// (fleet ruling). Furrow used to store a two-way `theme` = light/dark, and
/// 'light' was what every untouched install effectively had, so the
/// migration maps the old value dark -> dark and anything else -> follow
/// phone. It is read-time, not a one-off write, because a restored old
/// backup brings the old key back.
void main() {
  late AppDatabase db;
  late LocalSettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalSettingsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> legacy(String value) => db
      .into(db.userPrefs)
      .insert(UserPrefsCompanion.insert(key: 'theme', value: value));

  test('a fresh install follows the phone', () async {
    expect((await repo.getUserPrefs()).themeMode, OhThemeModePreference.system);
  });

  test('legacy dark stays dark', () async {
    await legacy('dark');
    expect((await repo.getUserPrefs()).themeMode, OhThemeModePreference.dark);
  });

  test('legacy light becomes follow phone', () async {
    await legacy('light');
    expect((await repo.getUserPrefs()).themeMode, OhThemeModePreference.system);
  });

  test('a chosen mode wins over the legacy key and round-trips', () async {
    await legacy('dark');
    for (final p in OhThemeModePreference.values) {
      await repo.setThemeMode(p);
      expect((await repo.getUserPrefs()).themeMode, p);
    }
  });

  test('restoring an old backup with theme=dark comes back dark', () async {
    await repo.setThemeMode(OhThemeModePreference.light);
    final old = jsonEncode({
      'app': 'furrow',
      'schemaVersion': 1,
      'exportedAt': '2026-07-01T00:00:00Z',
      'tables': {
        'habits': [],
        'habitMarks': [],
        'habitBadges': [],
        'userPrefs': [
          {'key': 'theme', 'value': 'dark'}
        ],
      },
    });
    await FurrowBackupSerializer(db).restoreAll(utf8.encode(old));
    expect((await repo.getUserPrefs()).themeMode, OhThemeModePreference.dark);
  });
}
