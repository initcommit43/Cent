import 'package:cent/core/database/app_database.dart';
import 'package:cent/core/money/currency.dart';
import 'package:cent/core/money/exchange_rate.dart';
import 'package:cent/core/money/money.dart';
import 'package:cent/data/accounts_repository.dart';
import 'package:cent/data/rates_repository.dart';
import 'package:cent/data/transactions_repository.dart';
import 'package:cent/features/insights/insights_math.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository tx;
  late int eur;
  late int usd;
  final cats = <String, int>{};
  final now = DateTime(2026, 10, 15, 12);
  final converter = CurrencyConverter(Currency.eur, [
    ExchangeRate(base: Currency.eur, quote: Currency.usd, rate: '1.25'),
  ]);

  Future<void> spend(
    String cat,
    int minor,
    DateTime at, {
    bool dollars = false,
  }) => tx.add(
    kind: TransactionKind.expense,
    accountId: dollars ? usd : eur,
    categoryId: cats[cat],
    amount: Money(minor, dollars ? Currency.usd : Currency.eur),
    title: cat,
    occurredAt: at,
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tx = TransactionsRepository(db);
    final accounts = AccountsRepository(db);
    eur = await accounts.create(
      name: 'Main',
      type: AccountType.checking,
      openingBalance: const Money.zero(Currency.eur),
    );
    usd = await accounts.create(
      name: 'Trip',
      type: AccountType.savings,
      openingBalance: const Money.zero(Currency.usd),
    );
    for (final name in ['Groceries', 'Eating out', 'Coffee']) {
      cats[name] = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: name,
              icon: 'receipt',
              tint: 'copper',
              kind: CategoryKind.expense,
            ),
          );
    }
  });

  tearDown(() => db.close());

  Future<Insights> compute({int top = 5}) async {
    final entries = await tx
        .watchRange(DateTime(2026, 4), DateTime(2026, 11))
        .first;
    return computeInsights(
      entries: entries,
      converter: converter,
      period: InsightPeriod.month,
      now: now,
      topCategories: top,
    );
  }

  test('shares are converted, sorted and add up', () async {
    await spend('Groceries', 10000, DateTime(2026, 10, 2));
    await spend(
      'Eating out',
      5000,
      DateTime(2026, 10, 3),
      dollars: true,
    ); // €40
    await spend('Coffee', 1000, DateTime(2026, 10, 4));

    final insights = await compute(top: 2);
    expect(insights.spent, const Money(15000, Currency.eur));
    expect(insights.shares.map((s) => s.category?.name), [
      'Groceries',
      'Eating out',
      null,
    ]);
    expect(insights.shares.last.amount.minor, 1000);
    expect(
      insights.shares.fold<double>(0, (s, x) => s + x.ratio),
      closeTo(1, 1e-9),
    );
  });

  test('compares with the same stretch of last month', () async {
    // September 1–15: €100 on eating out; later September spending ignored.
    await spend('Eating out', 10000, DateTime(2026, 9, 5));
    await spend('Eating out', 50000, DateTime(2026, 9, 25));
    await spend('Eating out', 8800, DateTime(2026, 10, 5));

    final comparison = (await compute()).comparison!;
    expect(comparison.category.name, 'Eating out');
    expect(comparison.less, isTrue);
    expect(comparison.percent, 12);
  });

  test('trend covers six months, oldest first', () async {
    await spend('Groceries', 2000, DateTime(2026, 5, 10));
    final trend = (await compute()).trend;
    expect(trend.map((m) => m.month.month), [5, 6, 7, 8, 9, 10]);
    expect(trend.first.spent.minor, 2000);
  });

  test('week ranges start on Monday', () {
    final range = periodRange(InsightPeriod.week, DateTime(2026, 10, 15));
    expect(range.start, DateTime(2026, 10, 12));
    expect(
      periodRange(InsightPeriod.week, DateTime(2026, 10, 15), offset: -1).start,
      DateTime(2026, 10, 5),
    );
  });
}
