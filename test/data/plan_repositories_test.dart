import 'package:cent/core/database/app_database.dart';
import 'package:cent/core/money/currency.dart';
import 'package:cent/core/money/money.dart';
import 'package:cent/data/accounts_repository.dart';
import 'package:cent/data/budgets_repository.dart';
import 'package:cent/data/goals_repository.dart';
import 'package:cent/data/recurrence.dart';
import 'package:cent/data/recurring_repository.dart';
import 'package:cent/data/transactions_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextOccurrence', () {
    test('clamps monthly rules to short months and recovers', () {
      final anchor = DateTime(2026, 1, 31, 8);
      final feb = nextOccurrence(
        anchor: anchor,
        from: anchor,
        frequency: Frequency.monthly,
      );
      expect(feb, DateTime(2026, 2, 28, 8));
      final mar = nextOccurrence(
        anchor: anchor,
        from: feb,
        frequency: Frequency.monthly,
      );
      expect(mar, DateTime(2026, 3, 31, 8));
    });

    test('steps weekly and yearly rules', () {
      final anchor = DateTime(2026, 10, 6);
      expect(
        nextOccurrence(
          anchor: anchor,
          from: DateTime(2026, 10, 14),
          frequency: Frequency.weekly,
        ),
        DateTime(2026, 10, 20),
      );
      expect(
        nextOccurrence(
          anchor: DateTime(2024, 2, 29),
          from: DateTime(2024, 3),
          frequency: Frequency.yearly,
        ),
        DateTime(2025, 2, 28),
      );
    });

    test('monthly equivalent of a yearly payment', () {
      expect(monthlyEquivalentMinor(12000, Frequency.yearly, 1), 1000);
      expect(monthlyEquivalentMinor(1000, Frequency.weekly, 1), 4333);
    });
  });

  group('repositories', () {
    late AppDatabase db;
    late int account;
    late int category;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      account = await AccountsRepository(db).create(
        name: 'Main',
        type: AccountType.checking,
        openingBalance: const Money.zero(Currency.eur),
      );
      category = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Subscriptions',
              icon: 'smartphone',
              tint: 'blush',
              kind: CategoryKind.expense,
            ),
          );
    });

    tearDown(() => db.close());

    test('materializes every missed occurrence once', () async {
      final entryId = await TransactionsRepository(db).add(
        kind: TransactionKind.expense,
        accountId: account,
        categoryId: category,
        amount: const Money(1399, Currency.eur),
        title: 'Netflix',
        occurredAt: DateTime(2026, 7, 2, 8),
      );
      final recurring = RecurringRepository(db);
      final ruleId = await recurring.createFromEntry(
        entryId: entryId,
        frequency: Frequency.monthly,
      );

      expect(await recurring.materializeDue(DateTime(2026, 10, 4)), 3);
      expect(await recurring.materializeDue(DateTime(2026, 10, 4)), 0);

      final history = await recurring.watchHistory(ruleId).first;
      expect(history.map((e) => e.occurredAt.month), [10, 9, 8, 7]);
      expect(history.every((e) => e.amountMinor == -1399), isTrue);

      final rule = (await recurring.watchOne(ruleId).first)!.rule;
      expect(rule.nextDue, DateTime(2026, 11, 2, 8));
    });

    test('paused rules create nothing; deleting keeps history', () async {
      final entryId = await TransactionsRepository(db).add(
        kind: TransactionKind.expense,
        accountId: account,
        categoryId: category,
        amount: const Money(1099, Currency.eur),
        title: 'Spotify',
        occurredAt: DateTime(2026, 9, 3),
      );
      final recurring = RecurringRepository(db);
      final ruleId = await recurring.createFromEntry(
        entryId: entryId,
        frequency: Frequency.monthly,
      );
      await recurring.setPaused(ruleId, paused: true);
      expect(await recurring.materializeDue(DateTime(2026, 12)), 0);

      await recurring.delete(ruleId);
      final kept = await db.select(db.transactions).get();
      expect(kept, hasLength(1));
      expect(kept.single.recurringRuleId, isNull);
    });

    test('goal completes when contributions reach the target', () async {
      final goals = GoalsRepository(db);
      final id = await goals.create(
        name: 'Bike',
        icon: 'gift',
        tint: 'brass',
        target: const Money(90000, Currency.eur),
        targetDate: DateTime(2027, 3),
      );

      await goals.contribute(
        id,
        const Money(50000, Currency.eur),
        at: DateTime(2026, 10),
      );
      var progress = (await goals.watchOne(id).first)!;
      expect(progress.ratio, closeTo(0.555, 0.001));
      expect(progress.goal.completedAt, isNull);
      // Oct to Mar is 6 months including this one: 400.00 / 6.
      expect(progress.monthlyNeeded(DateTime(2026, 10, 4))!.minor, 6667);

      await goals.contribute(
        id,
        const Money(40000, Currency.eur),
        at: DateTime(2026, 10, 4),
      );
      progress = (await goals.watchOne(id).first)!;
      expect(progress.isComplete, isTrue);
      expect(progress.goal.completedAt, DateTime(2026, 10, 4));
    });

    test('budget periods', () {
      final wed = DateTime(2026, 10, 7, 15);
      expect(
        budgetPeriod(BudgetPeriod.weekly, wed).start,
        DateTime(2026, 10, 5),
      );
      expect(budgetPeriod(BudgetPeriod.monthly, wed).end, DateTime(2026, 11));
      expect(budgetPeriod(BudgetPeriod.yearly, wed).start, DateTime(2026));
    });
  });
}
