import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../core/widgets/pressable.dart';
import '../../data/goals_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'goal_sheet.dart';
import 'plan_providers.dart';

List<Widget> goalsSlivers(BuildContext context, WidgetRef ref, double margin) {
  final l10n = AppLocalizations.of(context);
  final goals = ref.watch(goalsProvider).value;
  if (goals == null) return const [];

  if (goals.isEmpty) {
    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 64),
        sliver: SliverToBoxAdapter(
          child: EmptyState(
            icon: CentIcons.named('plane'),
            title: l10n.noGoalsTitle,
            body: l10n.noGoalsBody,
            action: CentButton(
              label: l10n.createGoal,
              icon: CentIcons.add,
              onPressed: () => unawaited(showGoalSheet(context)),
            ),
          ),
        ),
      ),
    ];
  }

  final active = goals.where((g) => g.goal.completedAt == null).toList();
  final done = goals.where((g) => g.goal.completedAt != null).toList();

  return [
    for (final g in active)
      SliverPadding(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 0),
        sliver: SliverToBoxAdapter(child: GoalCard(progress: g)),
      ),
    if (done.isNotEmpty)
      SliverPadding(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.xl, margin, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: l10n.completedGoals),
              CentGroup(
                children: [
                  for (var i = 0; i < done.length; i++)
                    _CompletedRow(
                      progress: done[i],
                      showDivider: i < done.length - 1,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
  ];
}

class GoalCard extends ConsumerWidget {
  const GoalCard({super.key, required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final goal = progress.goal;
    final now = ref.watch(clockProvider)();
    final monthly = progress.monthlyNeeded(now);
    final locale = Localizations.localeOf(context).toString();

    final note = monthly != null && goal.targetDate != null
        ? l10n.goalMonthlyByDate(
            formatMoney(monthly),
            DateFormat.yMMMM(locale).format(goal.targetDate!),
          )
        : l10n.goalNoDeadline;

    return Pressable(
      semanticLabel:
          '${goal.name}, ${l10n.savedOfTarget(formatMoney(progress.saved), formatMoney(progress.target))}',
      onTap: () => context.push(Routes.goal(goal.id)),
      child: CentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CategoryTile(
                  icon: CentIcons.named(goal.icon),
                  tint: CentTint.parse(goal.tint),
                ),
                const SizedBox(width: CentSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: CentType.headline.copyWith(color: c.ink),
                      ),
                      Text(
                        l10n.savedOfTarget(
                          formatMoney(progress.saved),
                          formatMoney(progress.target),
                        ),
                        style: CentType.subheadlineTabular.copyWith(
                          color: c.mute,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress.ratio * 100).floor()}%',
                  style: CentType.title2.copyWith(
                    color: c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CentSpace.md),
            CentProgressBar(value: progress.ratio, color: c.accentPatina),
            const SizedBox(height: CentSpace.sm),
            Text(note, style: CentType.footnote.copyWith(color: c.secondary)),
          ],
        ),
      ),
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.progress, required this.showDivider});

  final GoalProgress progress;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final goal = progress.goal;
    return InkWell(
      onTap: () => context.push(Routes.goal(goal.id)),
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CentSpace.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                CategoryTile(
                  icon: CentIcons.named(goal.icon),
                  tint: CentTint.parse(goal.tint),
                  size: 32,
                ),
                const SizedBox(width: CentSpace.md),
                Expanded(
                  child: Text(
                    goal.name,
                    style: CentType.body.copyWith(color: c.ink),
                  ),
                ),
                Icon(CentIcons.check, size: 18, color: c.positive),
                const SizedBox(width: 6),
                Text(
                  formatMoney(progress.target),
                  style: CentType.bodyTabular.copyWith(color: c.ink),
                ),
              ],
            ),
          ),
          if (showDivider) const InsetDivider(),
        ],
      ),
    );
  }
}
