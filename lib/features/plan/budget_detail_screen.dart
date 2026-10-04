import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/money/money_format.dart';
import '../../core/router/routes.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/charts/line_chart.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/widgets/entry_row.dart';
import 'budget_sheet.dart';
import 'plan_providers.dart';

final _budgetEntriesProvider = StreamProvider.autoDispose
    .family<List<EntryView>, BudgetProgress>((ref, p) {
      return ref
          .watch(transactionsRepositoryProvider)
          .watchRange(
            p.periodStart,
            p.periodEnd,
            filter: EntryFilter(
              kinds: const {TransactionKind.expense},
              categoryIds: {p.view.budget.categoryId},
            ),
          );
    });

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final budgets = ref.watch(budgetProgressProvider).value;
    final progress = budgets?.where((b) => b.view.budget.id == id).firstOrNull;

    ref.listen(budgetProgressProvider, (previous, next) {
      final existed =
          previous?.value?.any((b) => b.view.budget.id == id) ?? false;
      final exists = next.value?.any((b) => b.view.budget.id == id) ?? true;
      if (existed && !exists) context.pop();
    });

    if (progress == null) return const InlineScaffold(body: SizedBox.shrink());
    final entries = ref.watch(_budgetEntriesProvider(progress)).value;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final headline = progress.isOver
        ? l10n.amountOver(formatMoney(-progress.left))
        : l10n.amountLeft(formatMoney(progress.left));
    final resets = shortDate(context, progress.periodEnd);

    return InlineScaffold(
      title: progress.view.category.name,
      backLabel: l10n.tabPlan,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () =>
            unawaited(showBudgetSheet(context, existing: progress.view.budget)),
        child: Text(l10n.edit),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              headline,
              style: CentType.displayHero.copyWith(
                color: progress.isOver
                    ? c.negative
                    : progress.isClose
                    ? c.warning
                    : c.ink,
              ),
            ),
          ),
          Text(
            l10n.resetsOn(formatMoney(progress.limit), resets),
            textAlign: TextAlign.center,
            style: CentType.subheadline.copyWith(color: c.mute),
          ),
          const SizedBox(height: CentSpace.xl),
          if (entries != null)
            _PaceCard(progress: progress, entries: entries, now: now),
          const SizedBox(height: CentSpace.xl),
          if (entries != null && entries.isNotEmpty) ...[
            SectionHeader(
              title: l10n.inThisBudget,
              trailing: '${entries.length}',
            ),
            CentGroup(
              children: [
                for (var i = 0; i < entries.length; i++)
                  EntryRow(
                    view: entries[i],
                    now: now,
                    subtitle: EntrySubtitle.date,
                    showDivider: i < entries.length - 1,
                    onTap: () =>
                        context.push(Routes.planEntry(entries[i].entry.id)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaceCard extends ConsumerWidget {
  const _PaceCard({
    required this.progress,
    required this.entries,
    required this.now,
  });

  final BudgetProgress progress;
  final List<EntryView> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final converter = ref.watch(converterProvider).value;
    final base = progress.limit.currency;
    final start = progress.periodStart;
    final totalDays = progress.periodEnd.difference(start).inDays;
    final elapsed = (dateOnly(now).difference(start).inDays + 1).clamp(
      1,
      totalDays,
    );

    // Cumulative spending per day, in the base currency.
    final perDay = List<double>.filled(elapsed, 0);
    for (final e in entries) {
      final index = dateOnly(e.entry.occurredAt).difference(start).inDays;
      if (index < 0 || index >= elapsed || converter == null) continue;
      perDay[index] += converter.convert(e.amount, base).minor.abs();
    }
    for (var i = 1; i < perDay.length; i++) {
      perDay[i] += perDay[i - 1];
    }

    final evenPace = progress.limit.minor * elapsed / totalDays;
    final ahead = progress.spent.minor > evenPace;
    final daysLeft = totalDays - elapsed + 1;

    return CentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.spendingPace,
                  style: CentType.headline.copyWith(color: c.ink),
                ),
              ),
              Text(
                ahead ? l10n.aheadOfPace : l10n.onPace,
                style: CentType.subheadline.copyWith(
                  color: ahead ? c.warning : c.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: CentSpace.lg),
          CentLineChart(
            values: perDay,
            domain: totalDays,
            guide: progress.limit.minor.toDouble(),
            semanticLabel: l10n.paceSummary(
              (progress.ratio * 100).round(),
              l10n.daysLeft(daysLeft),
            ),
          ),
          const SizedBox(height: CentSpace.md),
          Row(
            children: [
              _Key(line: c.primary, label: l10n.paceSpent),
              const SizedBox(width: CentSpace.lg),
              _Key(line: c.mute, label: l10n.paceEven),
            ],
          ),
          const SizedBox(height: CentSpace.sm),
          Text(
            l10n.paceSummary(
              (progress.ratio * 100).round(),
              l10n.daysLeft(daysLeft),
            ),
            style: CentType.footnote.copyWith(color: c.mute),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.line, required this.label});

  final Color line;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: CentType.footnote.copyWith(color: context.colors.secondary),
      ),
    ],
  );
}
