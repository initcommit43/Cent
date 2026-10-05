import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';

class ActivityMonth extends Notifier<DateTime> {
  @override
  DateTime build() => monthStart(ref.read(clockProvider)());

  bool get isCurrent => state == monthStart(ref.read(clockProvider)());

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() {
    if (!isCurrent) state = DateTime(state.year, state.month + 1);
  }
}

final activityMonthProvider = NotifierProvider<ActivityMonth, DateTime>(
  ActivityMonth.new,
);

class ActivityFilter extends Notifier<EntryFilter> {
  @override
  EntryFilter build() => const EntryFilter();

  void apply(EntryFilter filter) => state = filter;

  void reset() => state = const EntryFilter();

  /// The quick chips under the search field: all, expenses, income,
  /// transfers. They replace the kind filter and keep everything else.
  void setKind(TransactionKind? kind) => state = EntryFilter(
    kinds: kind == null ? const {} : {kind},
    accountIds: state.accountIds,
    categoryIds: state.categoryIds,
    minAbsMinor: state.minAbsMinor,
    maxAbsMinor: state.maxAbsMinor,
  );
}

final activityFilterProvider = NotifierProvider<ActivityFilter, EntryFilter>(
  ActivityFilter.new,
);

final activityEntriesProvider = StreamProvider<List<EntryView>>((ref) {
  final month = ref.watch(activityMonthProvider);
  final filter = ref.watch(activityFilterProvider);
  return ref
      .watch(transactionsRepositoryProvider)
      .watchRange(month, nextMonthStart(month), filter: filter);
});

final searchResultsProvider = StreamProvider.autoDispose
    .family<List<EntryView>, String>((ref, query) {
      if (query.trim().isEmpty) return Stream.value(const []);
      return ref
          .watch(transactionsRepositoryProvider)
          .watchSearch(EntryFilter(query: query));
    });

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoriesRepositoryProvider).watchAll(),
);
