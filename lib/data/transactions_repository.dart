import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import '../core/money/money.dart';

class EntryView {
  const EntryView({
    required this.entry,
    required this.account,
    required this.category,
  });

  final LedgerEntry entry;
  final Account account;
  final Category? category;

  Money get amount => Money(entry.amountMinor, Currency.of(entry.currency));
}

class EntryFilter {
  const EntryFilter({
    this.kinds = const {},
    this.accountIds = const {},
    this.categoryIds = const {},
    this.minAbsMinor,
    this.maxAbsMinor,
    this.query = '',
  });

  final Set<TransactionKind> kinds;
  final Set<int> accountIds;
  final Set<int> categoryIds;
  final int? minAbsMinor;
  final int? maxAbsMinor;
  final String query;

  bool get isEmpty =>
      kinds.isEmpty &&
      accountIds.isEmpty &&
      categoryIds.isEmpty &&
      minAbsMinor == null &&
      maxAbsMinor == null &&
      query.trim().isEmpty;
}

class TransactionsRepository {
  TransactionsRepository(this._db);

  final AppDatabase _db;

  /// Entries with `from <= occurredAt < to`, newest first. Overview lists
  /// show each transfer once, from the sending side.
  Stream<List<EntryView>> watchRange(
    DateTime from,
    DateTime to, {
    EntryFilter filter = const EntryFilter(),
  }) {
    final query = _joined(hideIncomingTransfers: true)
      ..where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(from) &
            _db.transactions.occurredAt.isSmallerThanValue(to),
      );
    _applyFilter(query, filter);
    return query.watch().map(_toViews);
  }

  Stream<List<EntryView>> watchRecent({int limit = 5}) {
    final query = _joined(hideIncomingTransfers: true)..limit(limit);
    return query.watch().map(_toViews);
  }

  /// Searches all history, so results outside the visible month still show.
  Stream<List<EntryView>> watchSearch(EntryFilter filter, {int limit = 100}) {
    final query = _joined(hideIncomingTransfers: true)..limit(limit);
    _applyFilter(query, filter);
    return query.watch().map(_toViews);
  }

  Stream<List<EntryView>> watchForAccount(int accountId, {int limit = 50}) {
    final query = _joined()
      ..where(_db.transactions.accountId.equals(accountId))
      ..limit(limit);
    return query.watch().map(_toViews);
  }

  Stream<EntryView?> watchOne(int id) {
    final query = _joined()..where(_db.transactions.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toView(row),
    );
  }

  /// Stores an expense or income. [amount] is the unsigned value the user
  /// typed; the sign is derived from [kind].
  Future<int> add({
    required TransactionKind kind,
    required int accountId,
    required int? categoryId,
    required Money amount,
    required String title,
    required DateTime occurredAt,
    String? note,
    int? recurringRuleId,
  }) {
    assert(kind != TransactionKind.transfer, 'Use addTransfer');
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            kind: kind,
            amountMinor: _signed(kind, amount.minor),
            currency: amount.currency.code,
            title: title,
            note: Value(note),
            occurredAt: occurredAt,
            recurringRuleId: Value(recurringRuleId),
          ),
        );
  }

  /// Moves money between two accounts. [received] differs from [sent] when
  /// the accounts use different currencies.
  Future<void> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required Money sent,
    required Money received,
    required String title,
    required DateTime occurredAt,
    String? note,
  }) => _db.transaction(() async {
    final outId = await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: fromAccountId,
            kind: TransactionKind.transfer,
            amountMinor: -sent.minor.abs(),
            currency: sent.currency.code,
            title: title,
            note: Value(note),
            occurredAt: occurredAt,
          ),
        );
    final inId = await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: toAccountId,
            kind: TransactionKind.transfer,
            amountMinor: received.minor.abs(),
            currency: received.currency.code,
            title: title,
            note: Value(note),
            occurredAt: occurredAt,
            transferPeerId: Value(outId),
          ),
        );
    await (_db.update(_db.transactions)..where((t) => t.id.equals(outId)))
        .write(TransactionsCompanion(transferPeerId: Value(inId)));
  });

  Future<void> edit(
    int id, {
    required TransactionKind kind,
    required int accountId,
    required int? categoryId,
    required Money amount,
    required String title,
    required DateTime occurredAt,
    String? note,
  }) => (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
    TransactionsCompanion(
      kind: Value(kind),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      amountMinor: Value(_signed(kind, amount.minor)),
      currency: Value(amount.currency.code),
      title: Value(title),
      occurredAt: Value(occurredAt),
      note: Value(note),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Deletes an entry, and its other half when it's a transfer.
  Future<void> delete(int id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.transactions)..where(
          (t) =>
              t.id.equals(id) |
              (row.transferPeerId == null
                  ? const Constant(false)
                  : t.id.equals(row.transferPeerId!)),
        ))
        .go();
  });

  int _signed(TransactionKind kind, int minor) =>
      kind == TransactionKind.expense ? -minor.abs() : minor.abs();

  /// Number of entries and their total for [title] in the month containing
  /// [month], in that entry's currency.
  Future<({int count, int totalMinor})> merchantMonth(
    String title,
    String currency,
    DateTime month,
  ) async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n, COALESCE(SUM(amount_minor), 0) AS total '
          'FROM transactions WHERE title = ? AND currency = ? '
          "AND kind = 'expense' AND occurred_at >= ? AND occurred_at < ?",
          variables: [
            Variable.withString(title),
            Variable.withString(currency),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    return (count: row.read<int>('n'), totalMinor: row.read<int>('total'));
  }

  JoinedSelectStatement<HasResultSet, dynamic> _joined({
    bool hideIncomingTransfers = false,
  }) {
    final query =
        _db.select(_db.transactions).join([
          innerJoin(
            _db.accounts,
            _db.accounts.id.equalsExp(_db.transactions.accountId),
          ),
          leftOuterJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId),
          ),
        ])..orderBy([
          OrderingTerm.desc(_db.transactions.occurredAt),
          OrderingTerm.desc(_db.transactions.id),
        ]);
    if (hideIncomingTransfers) {
      final t = _db.transactions;
      query.where(
        t.kind.equalsValue(TransactionKind.transfer).not() |
            t.amountMinor.isSmallerThanValue(0),
      );
    }
    return query;
  }

  void _applyFilter(
    JoinedSelectStatement<HasResultSet, dynamic> query,
    EntryFilter filter,
  ) {
    final t = _db.transactions;
    if (filter.kinds.isNotEmpty) {
      query.where(t.kind.isIn(filter.kinds.map((k) => k.name)));
    }
    if (filter.accountIds.isNotEmpty) {
      query.where(t.accountId.isIn(filter.accountIds));
    }
    if (filter.categoryIds.isNotEmpty) {
      query.where(t.categoryId.isIn(filter.categoryIds));
    }
    final absAmount = t.amountMinor.abs();
    if (filter.minAbsMinor != null) {
      query.where(absAmount.isBiggerOrEqualValue(filter.minAbsMinor!));
    }
    if (filter.maxAbsMinor != null) {
      query.where(absAmount.isSmallerOrEqualValue(filter.maxAbsMinor!));
    }
    final text = filter.query.trim();
    if (text.isNotEmpty) {
      final pattern = '%${text.replaceAll('%', r'\%')}%';
      query.where(
        t.title.like(pattern) |
            t.note.like(pattern) |
            _db.categories.name.like(pattern),
      );
    }
  }

  List<EntryView> _toViews(List<TypedResult> rows) =>
      rows.map(_toView).toList();

  EntryView _toView(TypedResult row) => EntryView(
    entry: row.readTable(_db.transactions),
    account: row.readTable(_db.accounts),
    category: row.readTableOrNull(_db.categories),
  );
}
