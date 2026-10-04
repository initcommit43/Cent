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
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'budget_sheet.dart';
import 'plan_format.dart';
import 'plan_providers.dart';

List<Widget> budgetsSlivers(
  BuildContext context,
  WidgetRef ref,
  double margin,
) {
  final l10n = AppLocalizations.of(context);
  final budgets = ref.watch(budgetProgressProvider).value;
  if (budgets == null) return const [];

  if (budgets.isEmpty) {
    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 64),
        sliver: SliverToBoxAdapter(
          child: EmptyState(
            icon: CentIcons.target,
            title: l10n.noBudgetsTitle,
            body: l10n.noBudgetsBody,
            action: CentButton(
              label: l10n.createBudget,
              icon: CentIcons.add,
              onPressed: () => unawaited(showBudgetSheet(context)),
            ),
          ),
        ),
      ),
    ];
  }

  return [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(margin, CentSpace.lg, margin, 0),
      sliver: SliverToBoxAdapter(child: _MonthSummary(budgets: budgets)),
    ),
    SliverPadding(
      padding: EdgeInsets.fromLTRB(margin, CentSpace.xl, margin, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l10n.filterCategories,
              trailing: l10n.budgetCount(budgets.length),
            ),
            CentGroup(
              children: [
                for (var i = 0; i < budgets.length; i++)
                  BudgetRow(
                    progress: budgets[i],
                    showDivider: i < budgets.length - 1,
                    onTap: () =>
                        context.push(Routes.budget(budgets[i].view.budget.id)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  ];
}

class _MonthSummary extends ConsumerWidget {
  const _MonthSummary({required this.budgets});

  final List<BudgetProgress> budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final monthly = budgets.where(
      (b) => b.view.budget.period == BudgetPeriod.monthly,
    );
    if (monthly.isEmpty) return const SizedBox.shrink();

    final base = monthly.first.limit.currency;
    final limit = monthly.fold(Money.zero(base), (sum, b) => sum + b.limit);
    final spent = monthly.fold(Money.zero(base), (sum, b) => sum + b.spent);
    final left = limit - spent;
    final daysLeft = daysLeftInMonth(ref.watch(clockProvider)());
    final perDay = left.isNegative
        ? Money.zero(base)
        : Money((left.minor / daysLeft).round(), base);

    return CentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                left.isNegative
                    ? l10n.amountOver(formatMoney(-left))
                    : formatMoney(left),
                style: CentType.title1.copyWith(
                  color: left.isNegative ? c.negative : c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (!left.isNegative)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    l10n.leftOfTotal(formatMoney(limit)),
                    style: CentType.subheadlineTabular.copyWith(color: c.mute),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          CentProgressBar(
            value: spent.ratioOf(limit),
            color: spent > limit
                ? c.negative
                : spent.ratioOf(limit) >= 0.9
                ? c.warning
                : c.accentPatina,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.budgetSummaryFooter(
              l10n.daysLeft(daysLeft),
              formatMoney(perDay),
            ),
            style: CentType.footnote.copyWith(color: c.secondary),
          ),
        ],
      ),
    );
  }
}

class BudgetRow extends StatelessWidget {
  const BudgetRow({
    super.key,
    required this.progress,
    required this.onTap,
    this.showDivider = true,
  });

  final BudgetProgress progress;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final category = progress.view.category;
    final status = progress.isOver
        ? l10n.amountOver(formatMoney(-progress.left))
        : l10n.amountLeft(formatMoney(progress.left));

    return InkWell(
      onTap: onTap,
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CategoryTile(
                      icon: CentIcons.named(category.icon),
                      tint: CentTint.parse(category.tint),
                      size: 32,
                    ),
                    const SizedBox(width: CentSpace.md),
                    Expanded(
                      child: Text(
                        category.name,
                        style: CentType.body.copyWith(color: c.ink),
                      ),
                    ),
                    Text(
                      status,
                      style: CentType.subheadlineTabular.copyWith(
                        color: budgetTextColor(context, progress),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CentProgressBar(
                  value: progress.ratio,
                  color: budgetColor(context, progress),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.spentOf(
                    formatMoney(progress.spent),
                    formatMoney(progress.limit),
                  ),
                  style: CentType.footnote.copyWith(color: c.mute),
                ),
              ],
            ),
          ),
          if (showDivider) const InsetDivider(indent: CentSpace.lg),
        ],
      ),
    );
  }
}
