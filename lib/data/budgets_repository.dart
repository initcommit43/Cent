import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class BudgetsRepository {
  BudgetsRepository(this._db);

  final AppDatabase _db;

  /// Sum of all monthly budgets, in the base currency.
  Stream<int> watchMonthlyTotalMinor() {
    final total = _db.budgets.amountMinor.sum();
    final query = _db.selectOnly(_db.budgets)
      ..addColumns([total])
      ..where(_db.budgets.period.equalsValue(BudgetPeriod.monthly));
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }
}
