import 'dart:async';

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
import '../../core/widgets/cent_chip.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/search_field.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../transactions/entry_math.dart';
import '../transactions/widgets/entry_row.dart';
import 'activity_providers.dart';
import 'filter_sheet.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(activityEntriesProvider).value;
    final converter = ref.watch(converterProvider).value;
    final filter = ref.watch(activityFilterProvider);
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    final groups = entries == null ? null : groupByDay(entries);

    return LargeTitleScaffold(
      title: l10n.tabActivity,
      band: true,
      actions: [
        CentIconButton(
          icon: CentIcons.filter,
          label: l10n.filters,
          onPressed: () => showFilterSheet(context),
        ),
        CentIconButton(
          icon: CentIcons.add,
          label: l10n.addTransaction,
          onPressed: () => unawaited(showAddTransaction(context)),
        ),
      ],
      lead: _ActivityHeader(
        totals: entries == null || converter == null
            ? null
            : EntryTotals(entries, converter),
      ),
      slivers: [
        if (groups != null && groups.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: 72),
            sliver: SliverToBoxAdapter(
              child: filter.isEmpty
                  ? EmptyState(
                      icon: CentIcons.named('receipt'),
                      title: l10n.noTransactionsIn(
                        monthName(context, ref.watch(activityMonthProvider)),
                      ),
                      body: l10n.noTransactionsInBody,
                    )
                  : EmptyState(
                      icon: CentIcons.search,
                      title: l10n.noMatches,
                      body: l10n.noMatchesBody,
                      action: TextButton(
                        onPressed: ref
                            .read(activityFilterProvider.notifier)
                            .reset,
                        child: Text(l10n.clearFilters),
                      ),
                    ),
            ),
          ),
        if (groups != null)
          for (final (day, items) in groups)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margin, CentSpace.xl, margin, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: dayLabel(context, day, now),
                      trailing: converter == null
                          ? null
                          : _dayTotal(EntryTotals(items, converter).net),
                    ),
                    CentGroup(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          EntryRow(
                            view: items[i],
                            now: now,
                            showDivider: i < items.length - 1,
                            onTap: () => context.push(
                              Routes.activityEntry(items[i].entry.id),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String? _dayTotal(Money net) =>
      net.isZero ? null : formatMoney(net, sign: SignDisplay.always);
}

class _ActivityHeader extends ConsumerWidget {
  const _ActivityHeader({required this.totals});

  final EntryTotals? totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(activityMonthProvider);
    final monthNotifier = ref.read(activityMonthProvider.notifier);
    final kinds = ref.watch(activityFilterProvider).kinds;
    final selectedKind = kinds.length == 1 ? kinds.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _MonthArrow(
              icon: CentIcons.back,
              label: l10n.previousMonth,
              onTap: monthNotifier.previous,
            ),
            Text(
              monthYear(context, month),
              style: CentType.headline.copyWith(color: c.ink),
            ),
            _MonthArrow(
              icon: CentIcons.forward,
              label: l10n.nextMonth,
              onTap: monthNotifier.isCurrent ? null : monthNotifier.next,
            ),
            const Spacer(),
            if (totals != null)
              Text(
                l10n.spentSummary(formatMoney(totals!.spent)),
                style: CentType.subheadlineTabular.copyWith(color: c.secondary),
              ),
          ],
        ),
        const SizedBox(height: CentSpace.sm),
        CentSearchField(
          hint: l10n.searchTransactions,
          readOnly: true,
          onTap: () => context.push(Routes.activitySearch),
        ),
        const SizedBox(height: CentSpace.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (kind, label) in [
                (null, l10n.all),
                (TransactionKind.expense, l10n.expenses),
                (TransactionKind.income, l10n.income),
                (TransactionKind.transfer, l10n.transfers),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: CentSpace.sm),
                  child: CentChip(
                    label: label,
                    selected: selectedKind == kind,
                    onTap: () =>
                        ref.read(activityFilterProvider.notifier).setKind(kind),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CentSize.touchTarget,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? c.hairline : c.primaryText,
          ),
        ),
      ),
    );
  }
}
