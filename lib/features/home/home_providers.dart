import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/money/money.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../transactions/entry_math.dart';

class HomeSummary {
  const HomeSummary({
    required this.totalBalance,
    required this.month,
    required this.monthBudget,
  });

  final Money totalBalance;
  final EntryTotals month;

  /// Null when no monthly budgets exist.
  final Money? monthBudget;
}

final recentEntriesProvider = StreamProvider<List<EntryView>>(
  (ref) => ref.watch(transactionsRepositoryProvider).watchRecent(limit: 4),
);

final _currentMonthEntriesProvider = StreamProvider<List<EntryView>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(transactionsRepositoryProvider)
      .watchRange(monthStart(now), nextMonthStart(now));
});

final _monthlyBudgetProvider = StreamProvider<int>(
  (ref) => ref.watch(budgetsRepositoryProvider).watchMonthlyTotalMinor(),
);

final homeSummaryProvider = Provider<AsyncValue<HomeSummary>>((ref) {
  final converter = ref.watch(converterProvider);
  final accounts = ref.watch(accountsProvider);
  final month = ref.watch(_currentMonthEntriesProvider);
  final budget = ref.watch(_monthlyBudgetProvider);

  for (final async in [converter, accounts, month, budget]) {
    if (async.hasError) return AsyncError(async.error!, async.stackTrace!);
  }
  if (!converter.hasValue ||
      !accounts.hasValue ||
      !month.hasValue ||
      !budget.hasValue) {
    return const AsyncLoading();
  }

  final conv = converter.requireValue;
  var total = Money.zero(conv.base);
  for (final a in accounts.requireValue) {
    if (a.account.includeInNetWorth) {
      total += conv.convert(a.balance, conv.base);
    }
  }
  final budgetMinor = budget.requireValue;

  return AsyncData(
    HomeSummary(
      totalBalance: total,
      month: EntryTotals(month.requireValue, conv),
      monthBudget: budgetMinor == 0 ? null : Money(budgetMinor, conv.base),
    ),
  );
});
