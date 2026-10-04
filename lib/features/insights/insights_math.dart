import '../../core/database/app_database.dart';
import '../../core/money/money.dart';
import '../../data/rates_repository.dart';
import '../../data/transactions_repository.dart';

enum InsightPeriod { week, month, year }

typedef DateRange = ({DateTime start, DateTime end});

DateRange periodRange(InsightPeriod period, DateTime now, {int offset = 0}) =>
    switch (period) {
      InsightPeriod.week => () {
        final monday = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1) + 7 * offset,
        );
        return (start: monday, end: monday.add(const Duration(days: 7)));
      }(),
      InsightPeriod.month => (
        start: DateTime(now.year, now.month + offset),
        end: DateTime(now.year, now.month + offset + 1),
      ),
      InsightPeriod.year => (
        start: DateTime(now.year + offset),
        end: DateTime(now.year + offset + 1),
      ),
    };

class CategoryShare {
  const CategoryShare({
    required this.category,
    required this.amount,
    required this.count,
    required this.ratio,
  });

  /// Null for the combined "Other" share.
  final Category? category;
  final Money amount;
  final int count;
  final double ratio;
}

class MonthFlow {
  const MonthFlow(this.month, this.income, this.spent);

  final DateTime month;
  final Money income;
  final Money spent;
}

class Comparison {
  const Comparison(this.category, this.percent, {required this.less});

  final Category category;
  final int percent;
  final bool less;
}

class Insights {
  const Insights({
    required this.spent,
    required this.shares,
    required this.trend,
    required this.biggest,
    required this.comparison,
  });

  final Money spent;
  final List<CategoryShare> shares;
  final List<MonthFlow> trend;
  final List<EntryView> biggest;
  final Comparison? comparison;
}

/// Builds the Insights screen from raw entries. [entries] must cover the
/// previous period and the last six months; amounts are converted to the
/// base currency.
Insights computeInsights({
  required List<EntryView> entries,
  required CurrencyConverter converter,
  required InsightPeriod period,
  required DateTime now,
  int topCategories = 5,
}) {
  final base = converter.base;
  Money inBase(EntryView e) => converter.convert(e.amount, base).abs();

  final current = periodRange(period, now);
  final previous = periodRange(period, now, offset: -1);
  // Compare like with like: the same stretch of the previous period.
  final elapsed = now.difference(current.start);
  final previousCutoff = previous.start.add(elapsed);

  bool within(EntryView e, DateTime from, DateTime to) {
    final at = e.entry.occurredAt;
    return !at.isBefore(from) && at.isBefore(to);
  }

  final expenses = entries
      .where((e) => e.entry.kind == TransactionKind.expense)
      .toList();
  final inPeriod = expenses
      .where((e) => within(e, current.start, current.end))
      .toList();

  // Category shares, largest first.
  final byCategory = <int?, (Category?, int, int)>{};
  for (final e in inPeriod) {
    final key = e.category?.id;
    final prev = byCategory[key] ?? (e.category, 0, 0);
    byCategory[key] = (prev.$1, prev.$2 + inBase(e).minor, prev.$3 + 1);
  }
  final spentMinor = byCategory.values.fold<int>(0, (s, v) => s + v.$2);
  final sorted = byCategory.values.toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  final shares = <CategoryShare>[
    for (final (cat, minor, count) in sorted.take(topCategories))
      CategoryShare(
        category: cat,
        amount: Money(minor, base),
        count: count,
        ratio: spentMinor == 0 ? 0 : minor / spentMinor,
      ),
  ];
  final rest = sorted.skip(topCategories);
  if (rest.isNotEmpty) {
    final restMinor = rest.fold<int>(0, (s, v) => s + v.$2);
    shares.add(
      CategoryShare(
        category: null,
        amount: Money(restMinor, base),
        count: rest.fold<int>(0, (s, v) => s + v.$3),
        ratio: spentMinor == 0 ? 0 : restMinor / spentMinor,
      ),
    );
  }

  // Six months of income and spending, oldest first.
  final trend = <MonthFlow>[
    for (var i = 5; i >= 0; i--)
      () {
        final month = DateTime(now.year, now.month - i);
        final next = DateTime(now.year, now.month - i + 1);
        var income = Money.zero(base);
        var spent = Money.zero(base);
        for (final e in entries.where((e) => within(e, month, next))) {
          if (e.entry.kind == TransactionKind.income) income += inBase(e);
          if (e.entry.kind == TransactionKind.expense) spent += inBase(e);
        }
        return MonthFlow(month, income, spent);
      }(),
  ];

  final biggest = [...inPeriod]
    ..sort((a, b) => inBase(b).minor.compareTo(inBase(a).minor));

  return Insights(
    spent: Money(spentMinor, base),
    shares: shares,
    trend: trend,
    biggest: biggest.take(3).toList(),
    comparison: _comparison(
      expenses,
      current: (start: current.start, end: now),
      previous: (start: previous.start, end: previousCutoff),
      inBase: inBase,
    ),
  );
}

/// The category whose spending changed the most against the same stretch
/// of the previous period. Decreases win ties: good news first.
Comparison? _comparison(
  List<EntryView> expenses, {
  required DateRange current,
  required DateRange previous,
  required Money Function(EntryView) inBase,
}) {
  final now = <int, int>{};
  final before = <int, int>{};
  final categories = <int, Category>{};
  for (final e in expenses) {
    final cat = e.category;
    if (cat == null) continue;
    categories[cat.id] = cat;
    final at = e.entry.occurredAt;
    if (!at.isBefore(current.start) && at.isBefore(current.end)) {
      now[cat.id] = (now[cat.id] ?? 0) + inBase(e).minor;
    } else if (!at.isBefore(previous.start) && at.isBefore(previous.end)) {
      before[cat.id] = (before[cat.id] ?? 0) + inBase(e).minor;
    }
  }

  // Ignore categories under 2,000 minor units (€20) last period, where a
  // percentage would be noise.
  const threshold = 2000;
  Comparison? best;
  var bestScore = 0.0;
  for (final id in before.keys) {
    final prev = before[id]!;
    if (prev < threshold) continue;
    final cur = now[id] ?? 0;
    final change = (cur - prev) / prev;
    if (change.abs() < 0.1) continue;
    final score = change.abs() + (change < 0 ? 0.05 : 0);
    if (score > bestScore) {
      bestScore = score;
      best = Comparison(
        categories[id]!,
        (change.abs() * 100).round(),
        less: change < 0,
      );
    }
  }
  return best;
}
