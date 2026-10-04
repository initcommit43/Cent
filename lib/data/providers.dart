import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import 'accounts_repository.dart';
import 'categories_repository.dart';
import 'rates_repository.dart';
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
