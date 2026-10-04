import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import '../core/money/money.dart';

class AccountWithBalance {
  const AccountWithBalance(this.account, this.balance);

  final Account account;

  /// Opening balance plus every transaction, in the account's own currency.
  final Money balance;
}

class AccountsRepository {
  AccountsRepository(this._db);

  final AppDatabase _db;

  Stream<List<AccountWithBalance>> watchAll({bool includeArchived = false}) {
    final query = _db.customSelect(
      'SELECT a.*, a.opening_balance_minor + COALESCE(SUM(t.amount_minor), 0) '
      'AS balance_minor '
      'FROM accounts a '
      'LEFT JOIN transactions t ON t.account_id = a.id '
      '${includeArchived ? '' : 'WHERE a.archived = 0 '}'
      'GROUP BY a.id '
      'ORDER BY a.sort_order, a.id',
      readsFrom: {_db.accounts, _db.transactions},
    );

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          AccountWithBalance(
            _db.accounts.map(row.data),
            Money(
              row.read<int>('balance_minor'),
              Currency.of(row.read<String>('currency')),
            ),
          ),
      ],
    );
  }

  Stream<AccountWithBalance> watch(int id) =>
      watchAll(includeArchived: true)
          .map((all) => all.firstWhere((a) => a.account.id == id));

  Future<int> create({
    required String name,
    required AccountType type,
    required Money openingBalance,
    bool includeInNetWorth = true,
  }) async {
    final nextOrder = await _nextSortOrder();
    return _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            currency: openingBalance.currency.code,
            openingBalanceMinor: Value(openingBalance.minor),
            includeInNetWorth: Value(includeInNetWorth),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  /// End-of-day balances for each day from [from] to [today], oldest first.
  /// Works backwards from the current balance, so it stays correct no
  /// matter how old the account is.
  Stream<List<int>> watchDailyBalances(
    int accountId,
    DateTime from,
    DateTime today,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(today.year, today.month, today.day);
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.accountId.equals(accountId) &
            t.occurredAt.isBiggerOrEqualValue(start),
      );

    return watch(accountId).asyncMap((account) async {
      final entries = await query.get();
      final days = end.difference(start).inDays + 1;
      final changeByDay = List.filled(days, 0);
      for (final e in entries) {
        final at = e.occurredAt;
        final index = DateTime(
          at.year,
          at.month,
          at.day,
        ).difference(start).inDays;
        if (index >= 0 && index < days) changeByDay[index] += e.amountMinor;
      }

      final balances = List.filled(days, 0);
      var running = account.balance.minor;
      for (var i = days - 1; i >= 0; i--) {
        balances[i] = running;
        running -= changeByDay[i];
      }
      return balances;
    });
  }

  Future<void> update(
    int id, {
    required String name,
    required AccountType type,
    required int openingBalanceMinor,
    required bool includeInNetWorth,
  }) => (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
    AccountsCompanion(
      name: Value(name),
      type: Value(type),
      openingBalanceMinor: Value(openingBalanceMinor),
      includeInNetWorth: Value(includeInNetWorth),
    ),
  );

  Future<void> rename(int id, String name) => (_db.update(
    _db.accounts,
  )..where((a) => a.id.equals(id))).write(AccountsCompanion(name: Value(name)));

  Future<void> setArchived(int id, {required bool archived}) =>
      (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(archived: Value(archived)),
      );

  Future<int> _nextSortOrder() async {
    final max = _db.accounts.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.accounts,
    )..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }
}
