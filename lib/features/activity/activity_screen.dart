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
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/cent_chip.dart';
import '../../core/widgets/content_states.dart';
import '../../core/widgets/ghost.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/search_field.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../../l10n/app_localizations.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../transactions/entry_math.dart';
import '../transactions/widgets/entry_row.dart';
import 'activity_providers.dart';
import 'filter_sheet.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _setSearching(bool active) {
    setState(() {
      _searching = active;
      if (!active) {
        _search.clear();
        _query = '';
      }
    });
    if (!active) _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entriesAsync = ref.watch(activityEntriesProvider);
    final entries = entriesAsync.value;
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
      searchField: CentSearchField(
        placeholder: l10n.searchTransactions,
        controller: _search,
        focusNode: _searchFocus,
        onChanged: (value) => setState(() => _query = value),
      ),
      onSearchActiveChanged: _setSearching,
      lead: _searching
          ? null
          : _ActivityHeader(
              totals: entries == null || converter == null
                  ? null
                  : EntryTotals(entries, converter),
            ),
      slivers: _searching
          ? _searchSlivers(context, now, margin)
          : pendingSlivers(
                  [entriesAsync],
                  ghost: const _ActivityGhost(),
                  onRetry: () => reloadData(ref),
                ) ??
                [
                  if (groups != null && groups.isEmpty)
                    filter.isEmpty
                        ? stateSliver(
                            EmptyState(
                              preview: const _ActivityGhost(),
                              title: l10n.noTransactionsIn(
                                monthName(
                                  context,
                                  ref.watch(activityMonthProvider),
                                ),
                              ),
                              body: l10n.noTransactionsInBody,
                              // New entries default to today, so offering one
                              // from a past month would land somewhere else.
                              action:
                                  ref
                                      .watch(activityMonthProvider.notifier)
                                      .isCurrent
                                  ? CentButton(
                                      label: l10n.addTransaction,
                                      icon: CentIcons.add,
                                      onPressed: () => unawaited(
                                        showAddTransaction(context),
                                      ),
                                    )
                                  : null,
                            ),
                          )
                        : stateSliver(
                            top: 72,
                            EmptyState(
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
                  if (groups != null)
                    for (final (day, items) in groups)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          margin,
                          CentSpace.xl,
                          margin,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionHeader(
                                title: dayLabel(context, day, now),
                                trailing: converter == null
                                    ? null
                                    : _dayTotal(
                                        EntryTotals(items, converter).net,
                                      ),
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

  List<Widget> _searchSlivers(
    BuildContext context,
    DateTime now,
    double margin,
  ) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final query = _query.trim();
    final results = query.isEmpty
        ? const <EntryView>[]
        : ref.watch(searchResultsProvider(query)).value ?? const [];

    if (query.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(margin + CentSpace.lg, 20, margin, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              l10n.searchTip,
              style: CentType.footnote.copyWith(color: c.mute),
            ),
          ),
        ),
      ];
    }
    if (results.isEmpty) {
      return [
        stateSliver(
          top: 72,
          EmptyState(
            icon: CentIcons.search,
            title: l10n.noMatchesFor(query),
            body: l10n.noMatchesBody,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.lg, margin, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: l10n.resultsCount(results.length)),
              CentGroup(
                children: [
                  for (var i = 0; i < results.length; i++)
                    EntryRow(
                      view: results[i],
                      now: now,
                      subtitle: EntrySubtitle.date,
                      showDivider: i < results.length - 1,
                      onTap: () => context.push(
                        Routes.activityEntry(results[i].entry.id),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
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

class _ActivityGhost extends StatelessWidget {
  const _ActivityGhost();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          CentSpace.lg,
          CentSpace.sm,
          CentSpace.lg,
          CentSpace.md,
        ),
        child: Row(
          children: [
            GhostBar(width: 56, height: 8),
            Spacer(),
            GhostBar(width: 44, height: 8),
          ],
        ),
      ),
      GhostList(),
    ],
  );
}
