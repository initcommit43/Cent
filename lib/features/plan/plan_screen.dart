import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../l10n/app_localizations.dart';
import '../add_transaction/add_transaction_sheet.dart';
import 'budget_sheet.dart';
import 'budgets_section.dart';
import 'goal_sheet.dart';
import 'goals_section.dart';
import 'plan_providers.dart';
import 'recurring_section.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final section = ref.watch(planSectionProvider);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return LargeTitleScaffold(
      title: l10n.tabPlan,
      band: true,
      actions: [
        CentIconButton(
          icon: CentIcons.add,
          label: switch (section) {
            PlanSection.budgets => l10n.newBudget,
            PlanSection.goals => l10n.newGoal,
            PlanSection.recurring => l10n.addTransaction,
          },
          onPressed: () => unawaited(switch (section) {
            PlanSection.budgets => showBudgetSheet(context),
            PlanSection.goals => showGoalSheet(context),
            // Recurring payments start as a transaction with Repeat set.
            PlanSection.recurring => showAddTransaction(context),
          }),
        ),
      ],
      lead: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<PlanSection>(
          groupValue: section,
          backgroundColor: c.hairline,
          thumbColor: c.canvas,
          children: {
            for (final (s, label) in [
              (PlanSection.budgets, l10n.budgets),
              (PlanSection.goals, l10n.goals),
              (PlanSection.recurring, l10n.recurring),
            ])
              s: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  label,
                  style: CentType.subheadline.copyWith(color: c.ink),
                ),
              ),
          },
          onValueChanged: (s) {
            if (s == null) return;
            HapticFeedback.selectionClick();
            ref.read(planSectionProvider.notifier).select(s);
          },
        ),
      ),
      slivers: switch (section) {
        PlanSection.budgets => budgetsSlivers(context, ref, margin),
        PlanSection.goals => goalsSlivers(context, ref, margin),
        PlanSection.recurring => recurringSlivers(context, ref, margin),
      },
    );
  }
}
