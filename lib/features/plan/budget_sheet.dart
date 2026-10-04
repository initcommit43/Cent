import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/money/currency.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/amount_field.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../activity/activity_providers.dart';
import '../common/pickers.dart';
import 'plan_format.dart';
import 'plan_providers.dart';

/// Create a budget, or edit [existing].
Future<void> showBudgetSheet(BuildContext context, {Budget? existing}) =>
    showCentSheet<void>(
      context,
      grouped: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _BudgetSheet(existing: existing),
      ),
    );

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});

  final Budget? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late int? _categoryId = widget.existing?.categoryId;
  late BudgetPeriod _period = widget.existing?.period ?? BudgetPeriod.monthly;
  late final Currency _currency =
      ref.read(baseCurrencyProvider).value ?? Currency.eur;
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatAmountInput(widget.existing!.amountMinor, _currency),
  );

  int? get _amountMinor => parseAmountMinor(_amount.text, _currency);

  bool get _canSave => _categoryId != null && (_amountMinor ?? 0) > 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(budgetsRepositoryProvider)
        .save(
          id: widget.existing?.id,
          categoryId: _categoryId!,
          amountMinor: _amountMinor!,
          period: _period,
        );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(budgetsRepositoryProvider).delete(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final category = categories.where((x) => x.id == _categoryId).firstOrNull;
    // One budget per category: hide categories that already have one.
    final taken = <int>{
      for (final b
          in ref.watch(budgetProgressProvider).value ??
              const <BudgetProgress>[])
        if (b.view.budget.id != widget.existing?.id) b.view.budget.categoryId,
    };

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(text, style: CentType.footnote.copyWith(color: c.secondary)),
    );

    return Column(
      children: [
        SheetHeader(
          title: widget.existing == null ? l10n.newBudget : l10n.editBudget,
          cancelLabel: l10n.cancel,
          actionLabel: l10n.save,
          onAction: _canSave ? () => unawaited(_save()) : null,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 24),
            children: [
              CentCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: category == null
                      ? null
                      : CategoryTile(
                          icon: CentIcons.named(category.icon),
                          tint: CentTint.parse(category.tint),
                          size: 30,
                        ),
                  title: Text(
                    l10n.category,
                    style: CentType.body.copyWith(color: c.mute),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category?.name ?? '—',
                        style: CentType.body.copyWith(color: c.ink),
                      ),
                      Icon(CentIcons.forward, size: 18, color: c.mute),
                    ],
                  ),
                  onTap: () async {
                    final id = await pickCategory(
                      context,
                      kind: CategoryKind.expense,
                      selectedId: _categoryId,
                      exclude: taken,
                    );
                    if (id != null) setState(() => _categoryId = id);
                  },
                ),
              ),
              label(l10n.amount),
              AmountField(
                controller: _amount,
                currency: _currency,
                autofocus: widget.existing == null,
                onChanged: (_) => setState(() {}),
              ),
              label(l10n.period),
              CupertinoSlidingSegmentedControl<BudgetPeriod>(
                groupValue: _period,
                backgroundColor: c.hairline,
                thumbColor: c.canvas,
                children: {
                  for (final p in BudgetPeriod.values)
                    p: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        periodLabel(l10n, p),
                        style: CentType.subheadline.copyWith(color: c.ink),
                      ),
                    ),
                },
                onValueChanged: (p) {
                  if (p == null) return;
                  HapticFeedback.selectionClick();
                  setState(() => _period = p);
                },
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: CentSpace.xxl),
                CentButton(
                  label: l10n.deleteBudget,
                  style: CentButtonStyle.destructive,
                  expand: true,
                  onPressed: () => unawaited(_delete()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
