import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class BudgetView {
  const BudgetView(this.budget, this.category);

  final Budget budget;
  final Category category;
}

/// The period a budget covers on [now]: Monday to Sunday, the calendar
/// month, or the calendar year.
({DateTime start, DateTime end}) budgetPeriod(
  BudgetPeriod period,
  DateTime now,
) => switch (period) {
  BudgetPeriod.weekly => (
    start: DateTime(now.year, now.month, now.day - (now.weekday - 1)),
    end: DateTime(now.year, now.month, now.day - (now.weekday - 1) + 7),
  ),
  BudgetPeriod.monthly => (
    start: DateTime(now.year, now.month),
    end: DateTime(now.year, now.month + 1),
  ),
  BudgetPeriod.yearly => (
    start: DateTime(now.year),
    end: DateTime(now.year + 1),
  ),
};

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

  /// Budgets in the categories' order.
  Stream<List<BudgetView>> watchAll() {
    final query = _db.select(_db.budgets).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.budgets.categoryId),
      ),
    ])..orderBy([OrderingTerm.asc(_db.categories.sortOrder)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          BudgetView(row.readTable(_db.budgets), row.readTable(_db.categories)),
      ],
    );
  }

  Future<void> save({
    int? id,
    required int categoryId,
    required int amountMinor,
    required BudgetPeriod period,
  }) {
    final companion = BudgetsCompanion(
      categoryId: Value(categoryId),
      amountMinor: Value(amountMinor),
      period: Value(period),
    );
    if (id == null) return _db.into(_db.budgets).insert(companion);
    return (_db.update(
      _db.budgets,
    )..where((b) => b.id.equals(id))).write(companion);
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
}
