import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/settings/data/local_settings_repository.dart';
import 'package:furrow/features/settings/domain/user_prefs.dart';

void main() {
  late AppDatabase db;
  late LocalSettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalSettingsRepository(db);
  });

  tearDown(() => db.close());

  group('LocalSettingsRepository', () {
    test('time format defaults to 12-hour and persists', () async {
      expect((await repo.getUserPrefs()).timeFormat, TimeFormat.h12);
      await repo.setTimeFormat(TimeFormat.h24);
      expect((await repo.getUserPrefs()).timeFormat, TimeFormat.h24);
    });
  });
}
