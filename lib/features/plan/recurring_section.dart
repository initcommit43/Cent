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
import '../../core/widgets/content_states.dart';
import '../../core/widgets/ghost.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';
import '../../data/recurring_repository.dart';
import '../../l10n/app_localizations.dart';
import '../add_transaction/add_transaction_sheet.dart';
import 'plan_format.dart';
import 'plan_providers.dart';

List<Widget> recurringSlivers(
  BuildContext context,
  WidgetRef ref,
  double margin,
) {
  final l10n = AppLocalizations.of(context);
  final rulesAsync = ref.watch(rulesProvider);
  final converterAsync = ref.watch(converterProvider);
  final now = ref.watch(clockProvider)();
  final pending = pendingSlivers(
    [rulesAsync, converterAsync],
    ghost: const _RecurringGhost(),
    onRetry: () => reloadData(ref),
  );
  if (pending != null) return pending;
  final rules = rulesAsync.requireValue;
  final converter = converterAsync.requireValue;

  if (rules.isEmpty) {
    return [
      stateSliver(
        EmptyState(
          preview: const _RecurringGhost(),
          title: l10n.noRecurringTitle,
          body: l10n.noRecurringBody,
          action: CentButton(
            label: l10n.addTransaction,
            icon: CentIcons.add,
            onPressed: () => unawaited(showAddTransaction(context)),
          ),
        ),
      ),
    ];
  }

  final active = rules.where((r) => !r.rule.paused).toList();
  var monthly = Money.zero(converter.base);
  for (final r in active.where((r) => r.rule.kind == TransactionKind.expense)) {
    final perMonth = Money(
      monthlyEquivalentMinor(
        r.rule.amountMinor,
        r.rule.frequency,
        r.rule.interval,
      ),
      r.amount.currency,
    );
    monthly += converter.convert(perMonth, converter.base);
  }

  final today = dateOnly(now);
  final weekEnd = today.add(const Duration(days: 7));
  final monthEnd = nextMonthStart(now);
  final groups = <(String, List<RuleView>)>[
    (
      l10n.dueThisWeek,
      active.where((r) => r.rule.nextDue.isBefore(weekEnd)).toList(),
    ),
    (
      l10n.dueLaterThisMonth,
      active
          .where(
            (r) =>
                !r.rule.nextDue.isBefore(weekEnd) &&
                r.rule.nextDue.isBefore(monthEnd),
          )
          .toList(),
    ),
    (
      l10n.dueLater,
      active.where((r) => !r.rule.nextDue.isBefore(monthEnd)).toList(),
    ),
    (l10n.paused, rules.where((r) => r.rule.paused).toList()),
  ];

  return [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(margin, CentSpace.lg, margin, 0),
      sliver: SliverToBoxAdapter(
        child: CentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.fixedCostsMonthly(formatMoney(monthly)),
                style: CentType.title2.copyWith(
                  color: context.colors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.recurringCount(rules.length),
                style: CentType.footnote.copyWith(
                  color: context.colors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    for (final (title, items) in groups)
      if (items.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(margin, CentSpace.xl, margin, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: title),
                CentGroup(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      RuleRow(
                        view: items[i],
                        now: now,
                        showDivider: i < items.length - 1,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
  ];
}

class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.view,
    required this.now,
    this.showDivider = true,
  });

  final RuleView view;
  final DateTime now;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final rule = view.rule;
    final category = view.category;

    return InkWell(
      onTap: () => context.push(Routes.recurring(rule.id)),
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          Opacity(
            opacity: rule.paused ? 0.55 : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CentSize.row),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CentSpace.lg,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CategoryTile(
                      icon: CentIcons.named(category?.icon ?? 'receipt'),
                      tint: CentTint.parse(category?.tint ?? 'neutral'),
                    ),
                    const SizedBox(width: CentSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.title,
                            style: CentType.body.copyWith(color: c.ink),
                          ),
                          Text(
                            '${frequencyLabel(l10n, rule.frequency)} · ${dayLabel(context, rule.nextDue, now)}',
                            style: CentType.subheadline.copyWith(color: c.mute),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(view.amount, sign: SignDisplay.always),
                      style: CentType.bodyTabular.copyWith(
                        color: rule.kind == TransactionKind.income
                            ? c.positive
                            : c.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showDivider) const InsetDivider(),
        ],
      ),
    );
  }
}

class _RecurringGhost extends StatelessWidget {
  const _RecurringGhost();

  @override
  Widget build(BuildContext context) => const GhostList();
}
