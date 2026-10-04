import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/amount_field.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/cent_text_field.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/sheet.dart';
import '../../data/goals_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

const _goalIcons = [
  'plane', 'house', 'shield', 'monitor', 'car', 'graduation-cap', //
  'gift', 'heart', 'baby', 'dumbbell', 'music', 'piggy-bank',
];

/// Create a goal, or edit [existing].
Future<void> showGoalSheet(BuildContext context, {GoalProgress? existing}) =>
    showCentSheet<void>(
      context,
      grouped: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _GoalSheet(existing: existing),
      ),
    );

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({this.existing});

  final GoalProgress? existing;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  Goal? get _goal => widget.existing?.goal;

  late final Currency _currency = _goal == null
      ? ref.read(baseCurrencyProvider).value ?? Currency.eur
      : Currency.of(_goal!.currency);
  late final _name = TextEditingController(text: _goal?.name);
  late final _target = TextEditingController(
    text: _goal == null ? '' : formatAmountInput(_goal!.targetMinor, _currency),
  );
  late final _starting = TextEditingController();
  late String _icon = _goal?.icon ?? 'plane';
  late CentTint _tint = _goal == null
      ? CentTint.patina
      : CentTint.parse(_goal!.tint);
  late DateTime? _targetDate = _goal?.targetDate;

  int? get _targetMinor => parseAmountMinor(_target.text, _currency);
  int? get _startingMinor => parseAmountMinor(_starting.text, _currency);

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      (_targetMinor ?? 0) > 0 &&
      _startingMinor != null;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _starting.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(goalsRepositoryProvider);
    final startingNote = AppLocalizations.of(context).startingAmount;
    if (_goal != null) {
      await repo.update(
        _goal!.id,
        name: _name.text.trim(),
        icon: _icon,
        tint: _tint.name,
        targetMinor: _targetMinor!,
        targetDate: _targetDate,
      );
    } else {
      final id = await repo.create(
        name: _name.text.trim(),
        icon: _icon,
        tint: _tint.name,
        target: Money(_targetMinor!, _currency),
        targetDate: _targetDate,
      );
      if (_startingMinor! > 0) {
        await repo.contribute(
          id,
          Money(_startingMinor!, _currency),
          at: ref.read(clockProvider)(),
          note: startingNote,
        );
      }
    }
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        message: Text(l10n.deleteGoalConfirm(_goal!.name)),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text(l10n.deleteGoal),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(goalsRepositoryProvider).delete(_goal!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    var value = _targetDate ?? DateTime(now.year + 1, now.month);
    final picked = await showCentSheet<DateTime?>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: l10n.targetDate,
            cancelLabel: l10n.cancel,
            actionLabel: l10n.done,
            onAction: () => Navigator.of(sheetContext).pop(value),
          ),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.monthYear,
              initialDateTime: value,
              minimumDate: DateTime(now.year, now.month),
              onDateTimeChanged: (v) => value = v,
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(sheetContext).bottom + 12),
        ],
      ),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final locale = Localizations.localeOf(context).toString();

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(text, style: CentType.footnote.copyWith(color: c.secondary)),
    );

    return Column(
      children: [
        SheetHeader(
          title: _goal == null ? l10n.newGoal : l10n.editGoal,
          cancelLabel: l10n.cancel,
          actionLabel: l10n.save,
          onAction: _canSave ? () => unawaited(_save()) : null,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 32),
            children: [
              CentTextField(
                label: l10n.fieldName,
                hint: l10n.goalNameHint,
                controller: _name,
                autofocus: _goal == null,
                onChanged: (_) => setState(() {}),
              ),
              label(l10n.icon),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final icon in _goalIcons)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _icon = icon);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: icon == _icon
                                ? c.primary
                                : Colors.transparent,
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: CategoryTile(
                          icon: CentIcons.named(icon),
                          tint: _tint,
                          size: 48,
                        ),
                      ),
                    ),
                ],
              ),
              label(l10n.color),
              Row(
                children: [
                  for (final tint in CentTint.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _tint = tint);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: tint.foreground(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tint == _tint ? c.ink : Colors.transparent,
                              width: 2.5,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label(l10n.target),
              AmountField(
                controller: _target,
                currency: _currency,
                onChanged: (_) => setState(() {}),
              ),
              if (_goal == null) ...[
                label(l10n.startingAmount),
                AmountField(
                  controller: _starting,
                  currency: _currency,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 20),
              CentCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    l10n.targetDate,
                    style: CentType.body.copyWith(color: c.mute),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _targetDate == null
                            ? l10n.noTargetDate
                            : DateFormat.yMMMM(locale).format(_targetDate!),
                        style: CentType.body.copyWith(color: c.ink),
                      ),
                      if (_targetDate != null)
                        IconButton(
                          tooltip: l10n.clearDate,
                          icon: Icon(CentIcons.clear, size: 16, color: c.mute),
                          onPressed: () => setState(() => _targetDate = null),
                        )
                      else
                        Icon(CentIcons.forward, size: 18, color: c.mute),
                    ],
                  ),
                  onTap: () => unawaited(_pickDate()),
                ),
              ),
              if (_goal != null) ...[
                const SizedBox(height: CentSpace.xxl),
                CentButton(
                  label: l10n.deleteGoal,
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
