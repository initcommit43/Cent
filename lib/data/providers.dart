import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import 'accounts_repository.dart';
import 'backup_service.dart';
import 'budgets_repository.dart';
import 'categories_repository.dart';
import 'goals_repository.dart';
import 'onboarding_service.dart';
import 'rates_repository.dart';
import 'rates_service.dart';
import 'recurring_repository.dart';
import 'settings_repository.dart';
import 'transactions_repository.dart';

/// Overridden in tests with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountsRepositoryProvider = Provider(
  (ref) => AccountsRepository(ref.watch(databaseProvider)),
);

final categoriesRepositoryProvider = Provider(
  (ref) => CategoriesRepository(ref.watch(databaseProvider)),
);

final transactionsRepositoryProvider = Provider(
  (ref) => TransactionsRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final ratesRepositoryProvider = Provider(
  (ref) => RatesRepository(ref.watch(databaseProvider)),
);

final budgetsRepositoryProvider = Provider(
  (ref) => BudgetsRepository(ref.watch(databaseProvider)),
);

final goalsRepositoryProvider = Provider(
  (ref) => GoalsRepository(ref.watch(databaseProvider)),
);

final recurringRepositoryProvider = Provider(
  (ref) => RecurringRepository(ref.watch(databaseProvider)),
);

final accountsProvider = StreamProvider<List<AccountWithBalance>>(
  (ref) => ref.watch(accountsRepositoryProvider).watchAll(),
);

/// Source of "now", overridden in tests so date logic is deterministic.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final baseCurrencyProvider = StreamProvider<Currency>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.baseCurrency)
      .map((code) => code == null ? Currency.eur : Currency.of(code));
});

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.themeMode)
      .map(
        (name) => ThemeMode.values.firstWhere(
          (m) => m.name == name,
          orElse: () => ThemeMode.system,
        ),
      );
});

final converterProvider = StreamProvider<CurrencyConverter>((ref) async* {
  final base = await ref.watch(baseCurrencyProvider.future);
  yield* ref.watch(ratesRepositoryProvider).watchConverter(base);
});

final ratesServiceProvider = Provider(
  (ref) => RatesService(
    rates: ref.watch(ratesRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Prepares the database before the first frame.
final onboardingServiceProvider = Provider<OnboardingService>(
  (ref) => OnboardingService(ref.watch(databaseProvider)),
);

final onboardingDoneProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.onboardingDone)
      .map((v) => v == 'true'),
);

/// Runs before the first frame and resolves to whether onboarding is done,
/// so the router can pick the first screen without a flash.
final appStartupProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  if (!await settings.readBool(SettingKeys.onboardingDone)) return false;
  await ref
      .read(recurringRepositoryProvider)
      .materializeDue(ref.read(clockProvider)());
  // Runs in the background so a slow network never delays the first frame.
  // Read the setting directly: Riverpod pauses providers that nothing
  // listens to yet, so awaiting baseCurrencyProvider here would never finish.
  final code = await settings.read(SettingKeys.baseCurrency);
  final base = code == null ? Currency.eur : Currency.of(code);
  unawaited(ref.read(ratesServiceProvider).refreshIfStale(base));
  return true;
});
