import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import '../core/money/money.dart';
import 'recurrence.dart';

class RuleView {
  const RuleView({
    required this.rule,
    required this.account,
    required this.category,
  });

  final RecurringRule rule;
  final Account account;
  final Category? category;

  /// Signed like a transaction: negative for payments.
  Money get amount => Money(
    rule.kind == TransactionKind.expense
        ? -rule.amountMinor.abs()
        : rule.amountMinor.abs(),
    Currency.of(rule.currency),
  );
}

class RecurringRepository {
  RecurringRepository(this._db);

  final AppDatabase _db;

  /// Rules ordered by when they are next due.
  Stream<List<RuleView>> watchAll() => _joined().watch().map(_toViews);

  Stream<RuleView?> watchOne(int id) {
    final query = _joined()..where(_db.recurringRules.id.equals(id));
    return query.watchSingleOrNull().map((r) => r == null ? null : _toView(r));
  }

  /// Entries created from a rule, newest first.
  Stream<List<LedgerEntry>> watchHistory(int ruleId) =>
      (_db.select(_db.transactions)
            ..where((t) => t.recurringRuleId.equals(ruleId))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .watch();

  /// Creates a rule whose first occurrence is [entryId], already saved.
  Future<int> createFromEntry({
    required int entryId,
    required Frequency frequency,
    int interval = 1,
  }) => _db.transaction(() async {
    final entry = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(entryId))).getSingle();
    final id = await _db
        .into(_db.recurringRules)
        .insert(
          RecurringRulesCompanion.insert(
            accountId: entry.accountId,
            categoryId: Value(entry.categoryId),
            kind: entry.kind,
            amountMinor: entry.amountMinor.abs(),
            currency: entry.currency,
            title: entry.title,
            frequency: frequency,
            interval: Value(interval),
            anchorDate: entry.occurredAt,
            nextDue: nextOccurrence(
              anchor: entry.occurredAt,
              from: entry.occurredAt,
              frequency: frequency,
              interval: interval,
            ),
          ),
        );
    await (_db.update(_db.transactions)..where((t) => t.id.equals(entryId)))
        .write(TransactionsCompanion(recurringRuleId: Value(id)));
    return id;
  });

  Future<void> setPaused(int id, {required bool paused}) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(paused: Value(paused)),
      );

  Future<void> updateAmount(int id, Money amount) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(
          amountMinor: Value(amount.minor.abs()),
          currency: Value(amount.currency.code),
        ),
      );

  /// Deletes the rule but keeps the payments it already created.
  Future<void> delete(int id) => _db.transaction(() async {
    await (_db.update(_db.transactions)
          ..where((t) => t.recurringRuleId.equals(id)))
        .write(const TransactionsCompanion(recurringRuleId: Value(null)));
    await (_db.delete(_db.recurringRules)..where((r) => r.id.equals(id))).go();
  });

  /// Creates every occurrence due by [now] and moves each rule's next date
  /// forward. Safe to call on every launch.
  Future<int> materializeDue(DateTime now) => _db.transaction(() async {
    final due =
        await (_db.select(_db.recurringRules)..where(
              (r) =>
                  r.paused.equals(false) & r.nextDue.isSmallerOrEqualValue(now),
            ))
            .get();
    var created = 0;
    for (final rule in due) {
      var next = rule.nextDue;
      while (!next.isAfter(now)) {
        await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                accountId: rule.accountId,
                categoryId: Value(rule.categoryId),
                kind: rule.kind,
                amountMinor: rule.kind == TransactionKind.expense
                    ? -rule.amountMinor
                    : rule.amountMinor,
                currency: rule.currency,
                title: rule.title,
                occurredAt: next,
                recurringRuleId: Value(rule.id),
              ),
            );
        created++;
        next = nextOccurrence(
          anchor: rule.anchorDate,
          from: next,
          frequency: rule.frequency,
          interval: rule.interval,
        );
      }
      await (_db.update(_db.recurringRules)..where((r) => r.id.equals(rule.id)))
          .write(RecurringRulesCompanion(nextDue: Value(next)));
    }
    return created;
  });

  JoinedSelectStatement<HasResultSet, dynamic> _joined() =>
      _db.select(_db.recurringRules).join([
        innerJoin(
          _db.accounts,
          _db.accounts.id.equalsExp(_db.recurringRules.accountId),
        ),
        leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.recurringRules.categoryId),
        ),
      ])..orderBy([OrderingTerm.asc(_db.recurringRules.nextDue)]);

  List<RuleView> _toViews(List<TypedResult> rows) => rows.map(_toView).toList();

  RuleView _toView(TypedResult row) => RuleView(
    rule: row.readTable(_db.recurringRules),
    account: row.readTable(_db.accounts),
    category: row.readTableOrNull(_db.categories),
  );
}
