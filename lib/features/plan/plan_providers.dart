import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/money/money.dart';
import '../../data/budgets_repository.dart';
import '../../data/goals_repository.dart';
import '../../data/providers.dart';
import '../../data/rates_repository.dart';
import '../../data/recurring_repository.dart';
import '../../data/transactions_repository.dart';

enum PlanSection { budgets, goals, recurring }

class PlanSectionNotifier extends Notifier<PlanSection> {
  @override
  PlanSection build() => PlanSection.budgets;

  void select(PlanSection section) => state = section;
}

final planSectionProvider = NotifierProvider<PlanSectionNotifier, PlanSection>(
  PlanSectionNotifier.new,
);

class BudgetProgress {
  const BudgetProgress({
    required this.view,
    required this.spent,
    required this.limit,
    required this.periodStart,
    required this.periodEnd,
  });

  final BudgetView view;

  /// Expenses in the category this period, in the base currency.
  final Money spent;
  final Money limit;
  final DateTime periodStart;
  final DateTime periodEnd;

  Money get left => limit - spent;
  double get ratio => spent.ratioOf(limit);
  bool get isOver => spent > limit;

  /// Within 10% of the limit: time to slow down.
  bool get isClose => !isOver && ratio >= 0.9;
}

final _budgetsProvider = StreamProvider<List<BudgetView>>(
  (ref) => ref.watch(budgetsRepositoryProvider).watchAll(),
);

/// This year's expenses. A year covers every budget period, so one query
/// serves all budgets.
final _yearExpensesProvider = StreamProvider<List<EntryView>>((ref) {
  final year = budgetPeriod(BudgetPeriod.yearly, ref.watch(clockProvider)());
  return ref
      .watch(transactionsRepositoryProvider)
      .watchRange(
        year.start,
        year.end,
        filter: const EntryFilter(kinds: {TransactionKind.expense}),
      );
});

/// Budgets with what's been spent in their current period, live.
final budgetProgressProvider = Provider<AsyncValue<List<BudgetProgress>>>((
  ref,
) {
  final budgets = ref.watch(_budgetsProvider);
  final entries = ref.watch(_yearExpensesProvider);
  final converter = ref.watch(converterProvider);
  final now = ref.watch(clockProvider)();

  for (final async in [budgets, entries, converter]) {
    if (async.hasError) return AsyncError(async.error!, async.stackTrace!);
  }
  if (!budgets.hasValue || !entries.hasValue || !converter.hasValue) {
    return const AsyncLoading();
  }
  return AsyncData([
    for (final b in budgets.requireValue)
      _progress(b, entries.requireValue, converter.requireValue, now),
  ]);
});

BudgetProgress _progress(
  BudgetView view,
  List<EntryView> entries,
  CurrencyConverter converter,
  DateTime now,
) {
  final period = budgetPeriod(view.budget.period, now);
  var spent = Money.zero(converter.base);
  for (final e in entries) {
    final at = e.entry.occurredAt;
    if (e.entry.categoryId == view.budget.categoryId &&
        !at.isBefore(period.start) &&
        at.isBefore(period.end)) {
      spent += converter.convert(e.amount, converter.base).abs();
    }
  }
  return BudgetProgress(
    view: view,
    spent: spent,
    limit: Money(view.budget.amountMinor, converter.base),
    periodStart: period.start,
    periodEnd: period.end,
  );
}

final goalsProvider = StreamProvider<List<GoalProgress>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchAll(),
);

final rulesProvider = StreamProvider<List<RuleView>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchAll(),
);
