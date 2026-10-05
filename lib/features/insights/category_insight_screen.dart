import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/router/routes.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/charts/bar_charts.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../../l10n/app_localizations.dart';
import '../activity/activity_providers.dart';
import '../plan/plan_format.dart';
import '../plan/plan_providers.dart';
import '../transactions/widgets/entry_row.dart';

/// Expenses in the category for the last five weeks and this month.
final _categoryEntriesProvider = StreamProvider.autoDispose
    .family<List<EntryView>, int>((ref, id) {
      final now = ref.watch(clockProvider)();
      final fiveWeeks = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1) - 28,
      );
      final month = monthStart(now);
      return ref
          .watch(transactionsRepositoryProvider)
          .watchRange(
            fiveWeeks.isBefore(month) ? fiveWeeks : month,
            nextMonthStart(now),
            filter: EntryFilter(
              kinds: const {TransactionKind.expense},
              categoryIds: {id},
            ),
          );
    });

class CategoryInsightScreen extends ConsumerWidget {
  const CategoryInsightScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final category = (ref.watch(categoriesProvider).value ?? const [])
        .where((cat) => cat.id == id)
        .firstOrNull;
    final entries = ref.watch(_categoryEntriesProvider(id)).value;
    final converter = ref.watch(converterProvider).value;
    final budget = (ref.watch(budgetProgressProvider).value ?? const [])
        .where((b) => b.view.budget.categoryId == id)
        .firstOrNull;
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    if (category == null || entries == null || converter == null) {
      return const InlineScaffold(body: SizedBox.shrink());
    }

    final base = converter.base;
    Money inBase(EntryView e) => converter.convert(e.amount, base).abs();
    final month = monthStart(now);
    final thisMonth = entries
        .where((e) => !e.entry.occurredAt.isBefore(month))
        .toList();
    final monthTotal = thisMonth.fold(
      Money.zero(base),
      (s, e) => s + inBase(e),
    );
    final allSpent = ref.watch(_monthSpentProvider).value ?? monthTotal;

    // Five Monday-based weeks, oldest first.
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final weeks = [
      for (var i = 4; i >= 0; i--) thisMonday.subtract(Duration(days: 7 * i)),
    ];
    final weekly = [
      for (final start in weeks)
        entries
            .where(
              (e) =>
                  !e.entry.occurredAt.isBefore(start) &&
                  e.entry.occurredAt.isBefore(
                    start.add(const Duration(days: 7)),
                  ),
            )
            .fold(Money.zero(base), (s, e) => s + inBase(e)),
    ];

    return InlineScaffold(
      title: category.name,
      backLabel: l10n.tabInsights,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          Center(
            child: CategoryTile(
              icon: CentIcons.named(category.icon),
              tint: CentTint.parse(category.tint),
              size: 48,
            ),
          ),
          const SizedBox(height: CentSpace.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(monthTotal),
              style: CentType.displayHero.copyWith(color: c.ink),
            ),
          ),
          Text(
            l10n.shareOfSpending(
              allSpent.isZero
                  ? 0
                  : (monthTotal.ratioOf(allSpent) * 100).round(),
              thisMonth.length,
            ),
            textAlign: TextAlign.center,
            style: CentType.subheadline.copyWith(color: c.mute),
          ),
          if (budget != null) ...[
            const SizedBox(height: CentSpace.xl),
            CentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.monthlyBudget,
                          style: CentType.headline.copyWith(color: c.ink),
                        ),
                      ),
                      Text(
                        formatMoney(budget.limit),
                        style: CentType.bodyTabular.copyWith(color: c.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CentProgressBar(
                    value: budget.ratio,
                    color: budgetColor(context, budget),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    budget.isOver
                        ? l10n.amountOver(formatMoney(-budget.left))
                        : l10n.amountLeft(formatMoney(budget.left)),
                    style: CentType.footnote.copyWith(
                      color: budgetTextColor(context, budget),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: CentSpace.lg),
          CentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.byWeek,
                  style: CentType.title2.copyWith(color: c.ink),
                ),
                const SizedBox(height: CentSpace.lg),
                GroupedBars(
                  height: 140,
                  semanticLabel: l10n.chartCategorySummary(
                    category.name,
                    formatMoney(weekly.last),
                  ),
                  valueLabels: [
                    for (final w in weekly) formatMoney(w, whole: true),
                  ],
                  groups: [
                    for (var i = 0; i < weeks.length; i++)
                      (
                        shortDate(context, weeks[i]),
                        [
                          (
                            weekly[i].minor.toDouble(),
                            i == weeks.length - 1
                                ? c.accentCopper
                                : c.accentCopperSoft,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (thisMonth.isNotEmpty) ...[
            const SizedBox(height: CentSpace.xl),
            SectionHeader(
              title: monthName(context, now),
              trailing: '${thisMonth.length}',
            ),
            CentGroup(
              children: [
                for (var i = 0; i < thisMonth.length; i++)
                  EntryRow(
                    view: thisMonth[i],
                    now: now,
                    subtitle: EntrySubtitle.date,
                    showDivider: i < thisMonth.length - 1,
                    onTap: () => context.push(
                      Routes.insightsEntry(thisMonth[i].entry.id),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// All expenses this month in the base currency, for the share line.
final _monthSpentProvider = StreamProvider.autoDispose<Money>((ref) async* {
  final now = ref.watch(clockProvider)();
  final converter = await ref.watch(converterProvider.future);
  yield* ref
      .watch(transactionsRepositoryProvider)
      .watchRange(
        monthStart(now),
        nextMonthStart(now),
        filter: const EntryFilter(kinds: {TransactionKind.expense}),
      )
      .map(
        (entries) => entries.fold(
          Money.zero(converter.base),
          (s, e) => s + converter.convert(e.amount, converter.base).abs(),
        ),
      );
});
