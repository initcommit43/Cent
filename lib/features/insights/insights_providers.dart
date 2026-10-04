import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import 'insights_math.dart';

class InsightsPeriodNotifier extends Notifier<InsightPeriod> {
  @override
  InsightPeriod build() => InsightPeriod.month;

  void select(InsightPeriod period) => state = period;
}

final insightsPeriodProvider =
    NotifierProvider<InsightsPeriodNotifier, InsightPeriod>(
      InsightsPeriodNotifier.new,
    );

/// Enough history for the six-month trend and the previous period.
final _entriesProvider = StreamProvider<List<EntryView>>((ref) {
  final now = ref.watch(clockProvider)();
  final period = ref.watch(insightsPeriodProvider);
  final previous = periodRange(period, now, offset: -1).start;
  final sixMonths = DateTime(now.year, now.month - 5);
  final from = previous.isBefore(sixMonths) ? previous : sixMonths;
  return ref
      .watch(transactionsRepositoryProvider)
      .watchRange(from, periodRange(period, now).end);
});

final insightsProvider = Provider<AsyncValue<Insights>>((ref) {
  final entries = ref.watch(_entriesProvider);
  final converter = ref.watch(converterProvider);
  if (entries.hasError) return AsyncError(entries.error!, entries.stackTrace!);
  if (converter.hasError) {
    return AsyncError(converter.error!, converter.stackTrace!);
  }
  if (!entries.hasValue || !converter.hasValue) return const AsyncLoading();
  return AsyncData(
    computeInsights(
      entries: entries.requireValue,
      converter: converter.requireValue,
      period: ref.watch(insightsPeriodProvider),
      now: ref.watch(clockProvider)(),
    ),
  );
});
