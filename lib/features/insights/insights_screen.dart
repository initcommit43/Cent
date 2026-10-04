import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/widgets/entry_row.dart';
import 'insights_math.dart';
import 'insights_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(insightsPeriodProvider);
    final insights = ref.watch(insightsProvider).value;
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    Widget section(Widget child, {double top = CentSpace.lg}) => SliverPadding(
      padding: EdgeInsets.fromLTRB(margin, top, margin, 0),
      sliver: SliverToBoxAdapter(child: child),
    );

    return LargeTitleScaffold(
      title: l10n.tabInsights,
      band: true,
      lead: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<InsightPeriod>(
          groupValue: period,
          backgroundColor: c.hairline,
          thumbColor: c.canvas,
          children: {
            for (final (p, label) in [
              (InsightPeriod.week, l10n.periodWeek),
              (InsightPeriod.month, l10n.periodMonth),
              (InsightPeriod.year, l10n.periodYear),
            ])
              p: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  label,
                  style: CentType.subheadline.copyWith(color: c.ink),
                ),
              ),
          },
          onValueChanged: (p) {
            if (p == null) return;
            HapticFeedback.selectionClick();
            ref.read(insightsPeriodProvider.notifier).select(p);
          },
        ),
      ),
      slivers: insights == null
          ? const []
          : [
              if (insights.spent.isZero)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 64),
                  sliver: SliverToBoxAdapter(
                    child: EmptyState(
                      icon: CentIcons.named('receipt'),
                      title: l10n.noSpendingTitle,
                      body: l10n.noSpendingBody,
                    ),
                  ),
                )
              else ...[
                section(
                  _CategoryCard(insights: insights, period: period, now: now),
                ),
                section(_TrendCard(trend: insights.trend)),
                if (insights.comparison != null)
                  section(
                    CentCard(
                      color: c.cream,
                      child: Text(
                        _comparisonText(
                          context,
                          insights.comparison!,
                          period,
                          now,
                        ),
                        style: CentType.callout.copyWith(color: c.ink),
                      ),
                    ),
                  ),
                if (insights.biggest.isNotEmpty)
                  section(
                    top: CentSpace.xl,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: l10n.biggestExpenses),
                        CentGroup(
                          children: [
                            for (var i = 0; i < insights.biggest.length; i++)
                              EntryRow(
                                view: insights.biggest[i],
                                now: now,
                                subtitle: EntrySubtitle.date,
                                showDivider: i < insights.biggest.length - 1,
                                onTap: () => context.push(
                                  Routes.insightsEntry(
                                    insights.biggest[i].entry.id,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],
    );
  }

  String _comparisonText(
    BuildContext context,
    Comparison comparison,
    InsightPeriod period,
    DateTime now,
  ) {
    final l10n = AppLocalizations.of(context);
    final previous = switch (period) {
      InsightPeriod.week => l10n.previousWeek,
      InsightPeriod.month => l10n.inMonth(
        monthName(context, DateTime(now.year, now.month - 1)),
      ),
      InsightPeriod.year => l10n.previousYear,
    };
    final category = comparison.category.name.toLowerCase();
    return comparison.less
        ? l10n.insightLess(comparison.percent, category, previous)
        : l10n.insightMore(comparison.percent, category, previous);
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.insights,
    required this.period,
    required this.now,
  });

  final Insights insights;
  final InsightPeriod period;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final when = switch (period) {
      InsightPeriod.week => l10n.thisWeek,
      InsightPeriod.month => monthName(context, now),
      InsightPeriod.year => '${now.year}',
    };

    return CentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.spendingByCategory,
            style: CentType.title2.copyWith(color: c.ink),
          ),
          const SizedBox(height: CentSpace.md),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                formatMoney(insights.spent),
                style: CentType.title1.copyWith(
                  color: c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  period == InsightPeriod.week
                      ? when
                      : l10n.inPeriodSoFar(when),
                  style: CentType.subheadline.copyWith(color: c.mute),
                ),
              ),
            ],
          ),
          const SizedBox(height: CentSpace.md),
          // Segments use each category's own color so they match the tiles
          // below; the gaps keep neighbours apart when colors repeat.
          StackedBar(
            parts: [
              for (final share in insights.shares)
                (
                  share.ratio,
                  share.category == null
                      ? c.mute
                      : CentTint.parse(share.category!.tint).foreground(c),
                ),
            ],
          ),
          const SizedBox(height: CentSpace.sm),
          for (final share in insights.shares) _ShareRow(share: share),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share});

  final CategoryShare share;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final category = share.category;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryTile(
            icon: CentIcons.named(category?.icon ?? 'ellipsis'),
            tint: CentTint.parse(category?.tint ?? 'neutral'),
            size: 32,
          ),
          const SizedBox(width: CentSpace.md),
          Expanded(
            child: Text(
              category?.name ?? l10n.otherCategories,
              style: CentType.body.copyWith(color: c.ink),
            ),
          ),
          Text(
            '${(share.ratio * 100).round()}%',
            style: CentType.subheadlineTabular.copyWith(color: c.mute),
          ),
          SizedBox(
            width: 96,
            child: Text(
              formatMoney(share.amount),
              textAlign: TextAlign.right,
              style: CentType.bodyTabular.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );

    if (category == null) return row;
    return InkWell(
      onTap: () => context.push(Routes.insightsCategory(category.id)),
      highlightColor: c.hairline.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(CentRadius.md),
      child: row,
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final List<MonthFlow> trend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final base = trend.first.income.currency;
    final income = trend.fold(Money.zero(base), (s, m) => s + m.income);
    final spent = trend.fold(Money.zero(base), (s, m) => s + m.spent);
    final kept = income - spent;

    return CentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.incomeAndSpending,
            style: CentType.title2.copyWith(color: c.ink),
          ),
          const SizedBox(height: CentSpace.lg),
          GroupedBars(
            semanticLabel: l10n.chartTrendSummary,
            groups: [
              for (var i = 0; i < trend.length; i++)
                (
                  DateFormat.MMM(locale).format(trend[i].month),
                  [
                    (trend[i].income.minor.toDouble(), c.accentPatina),
                    (
                      trend[i].spent.minor.toDouble(),
                      i == trend.length - 1
                          ? c.accentCopper
                          : c.accentCopperSoft,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: CentSpace.md),
          Row(
            children: [
              _Legend(color: c.accentPatina, label: l10n.incomeLabel),
              const SizedBox(width: CentSpace.lg),
              _Legend(color: c.accentCopper, label: l10n.spendingLabel),
            ],
          ),
          const SizedBox(height: CentSpace.sm),
          Text(
            kept.isNegative
                ? l10n.trendSummaryOverspent(formatMoney(-kept))
                : l10n.trendSummaryKept(formatMoney(kept)),
            style: CentType.footnote.copyWith(color: c.mute),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
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
