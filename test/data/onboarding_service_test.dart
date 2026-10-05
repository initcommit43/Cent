import 'package:cent/core/database/app_database.dart';
import 'package:cent/core/money/currency.dart';
import 'package:cent/core/money/money.dart';
import 'package:cent/data/accounts_repository.dart';
import 'package:cent/data/default_categories.dart';
import 'package:cent/data/onboarding_service.dart';
import 'package:cent/data/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'a fresh start creates one account and the default categories',
    () async {
      await OnboardingService(db).startFresh(
        base: Currency.chf,
        accountName: 'Everyday',
        accountType: AccountType.checking,
        openingBalance: const Money(-12050, Currency.chf),
        appLock: true,
      );

      final accounts = await AccountsRepository(db).watchAll().first;
      expect(accounts, hasLength(1));
      expect(accounts.single.account.name, 'Everyday');
      expect(accounts.single.balance, const Money(-12050, Currency.chf));
      expect(
        await db.select(db.categories).get(),
        hasLength(defaultCategories.length),
      );
      expect(await db.select(db.transactions).get(), isEmpty);

      final settings = SettingsRepository(db);
      expect(await settings.read(SettingKeys.baseCurrency), 'CHF');
      expect(await settings.readBool(SettingKeys.appLock), isTrue);
      expect(await settings.readBool(SettingKeys.onboardingDone), isTrue);
      expect(await settings.readBool(SettingKeys.demoData), isFalse);
    },
  );

  test('demo data keeps the app lock choice', () async {
    await OnboardingService(db)
        .startWithDemo(now: DateTime(2026, 10, 4), appLock: true);

    final settings = SettingsRepository(db);
    expect(await settings.readBool(SettingKeys.demoData), isTrue);
    expect(await settings.readBool(SettingKeys.appLock), isTrue);
    expect(await db.select(db.transactions).get(), isNotEmpty);
  });
}
