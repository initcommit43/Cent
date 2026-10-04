import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import '../core/money/money.dart';
import 'accounts_repository.dart';
import 'categories_repository.dart';
import 'default_categories.dart';
import 'demo_seeder.dart';
import 'settings_repository.dart';

/// Applies the choices made during onboarding in one transaction, so a
/// crash halfway never leaves a half-set-up app.
class OnboardingService {
  OnboardingService(this._db);

  final AppDatabase _db;

  Future<void> startFresh({
    required Currency base,
    required String accountName,
    required AccountType accountType,
    required Money openingBalance,
    required bool appLock,
  }) => _db.transaction(() async {
    final categories = CategoriesRepository(_db);
    for (final c in defaultCategories) {
      await categories.create(
        name: c.name,
        icon: c.icon,
        tint: c.tint,
        kind: c.kind,
      );
    }
    await AccountsRepository(_db).create(
      name: accountName,
      type: accountType,
      openingBalance: openingBalance,
    );
    final settings = SettingsRepository(_db);
    await settings.write(SettingKeys.baseCurrency, base.code);
    await settings.writeBool(SettingKeys.appLock, value: appLock);
    await settings.writeBool(SettingKeys.onboardingDone, value: true);
  });

  Future<void> startWithDemo({required DateTime now, required bool appLock}) =>
      _db.transaction(() async {
        await DemoSeeder(_db, now: now).seed();
        await SettingsRepository(_db)
            .writeBool(SettingKeys.appLock, value: appLock);
      });
}
