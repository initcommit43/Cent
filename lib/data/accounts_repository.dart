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
