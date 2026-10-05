import '../core/database/app_database.dart';

/// Keys for the key/value settings table.
abstract final class SettingKeys {
  static const baseCurrency = 'base_currency';
  static const themeMode = 'theme_mode';
  static const onboardingDone = 'onboarding_done';
  static const appLock = 'app_lock';
  static const appLockAfterSeconds = 'app_lock_after_seconds';
  static const blurInSwitcher = 'blur_in_switcher';
  static const demoData = 'demo_data';
  static const ratesUpdatedAt = 'rates_updated_at';
  static const lastBackupAt = 'last_backup_at';
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<String?> watch(String key) => (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).watchSingleOrNull().map((s) => s?.value);

  Future<String?> read(String key) async => (await (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> remove(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  Future<bool> readBool(String key) async => await read(key) == 'true';

  Future<void> writeBool(String key, {required bool value}) =>
      write(key, value.toString());
}
