import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/cent_theme.dart';
import '../../l10n/app_localizations.dart';
import 'plan_providers.dart';

String frequencyLabel(AppLocalizations l10n, Frequency frequency) =>
    switch (frequency) {
      Frequency.weekly => l10n.everyWeek,
      Frequency.monthly => l10n.everyMonth,
      Frequency.yearly => l10n.everyYear,
    };

String periodLabel(AppLocalizations l10n, BudgetPeriod period) =>
    switch (period) {
      BudgetPeriod.weekly => l10n.periodWeekly,
      BudgetPeriod.monthly => l10n.periodMonthly,
      BudgetPeriod.yearly => l10n.periodYearly,
    };

/// Patina while on track, brass close to the limit, red only when over.
Color budgetColor(BuildContext context, BudgetProgress p) {
  final c = context.colors;
  if (p.isOver) return c.negative;
  if (p.isClose) return c.warning;
  return c.accentPatina;
}

/// Text color for the "left" or "over" label next to a budget.
Color budgetTextColor(BuildContext context, BudgetProgress p) {
  final c = context.colors;
  if (p.isOver) return c.negative;
  if (p.isClose) return c.warning;
  return c.mute;
}
