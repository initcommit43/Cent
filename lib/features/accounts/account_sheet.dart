import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../core/widgets/cent_chip.dart';
import '../../core/widgets/cent_text_field.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../common/pickers.dart';
import 'account_style.dart';

/// Opens the account form; pass [account] to edit instead of create.
Future<void> showAccountSheet(BuildContext context, {Account? account}) =>
    showCentSheet<void>(
      context,
      grouped: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _AccountSheet(account: account),
      ),
    );

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.account});

  final Account? account;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final _name = TextEditingController(text: widget.account?.name);
  late final _balance = TextEditingController(
    text: widget.account == null
        ? ''
        : formatAmountInput(
            widget.account!.openingBalanceMinor,
            Currency.of(widget.account!.currency),
          ),
  );
  late AccountType _type = widget.account?.type ?? AccountType.checking;
  late Currency _currency = widget.account == null
      ? ref.read(baseCurrencyProvider).value ?? Currency.eur
      : Currency.of(widget.account!.currency);
  late bool _includeInNetWorth = widget.account?.includeInNetWorth ?? true;

  bool get _editing => widget.account != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  int? get _openingMinor =>
      parseAmountMinor(_balance.text, _currency, allowNegative: true);

  bool get _canSave => _name.text.trim().isNotEmpty && _openingMinor != null;

  Future<void> _save() async {
    final repo = ref.read(accountsRepositoryProvider);
    if (_editing) {
      await repo.update(
        widget.account!.id,
        name: _name.text.trim(),
        type: _type,
        openingBalanceMinor: _openingMinor!,
        includeInNetWorth: _includeInNetWorth,
      );
    } else {
      await repo.create(
        name: _name.text.trim(),
        type: _type,
        openingBalance: Money(_openingMinor!, _currency),
        includeInNetWorth: _includeInNetWorth,
      );
    }
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        message: Text(l10n.archiveAccountConfirm(widget.account!.name)),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text(l10n.archiveAccount),
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
    await ref
        .read(accountsRepositoryProvider)
        .setArchived(widget.account!.id, archived: true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(text, style: CentType.footnote.copyWith(color: c.secondary)),
    );

    return Column(
      children: [
        SheetHeader(
          title: _editing ? l10n.editAccount : l10n.newAccount,
          cancelLabel: l10n.cancel,
          actionLabel: l10n.save,
          onAction: _canSave ? () => unawaited(_save()) : null,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              margin,
              CentSpace.md,
              margin,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              CentTextField(
                label: l10n.fieldName,
                hint: l10n.accountNameHint,
                controller: _name,
                autofocus: !_editing,
                capitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              label(l10n.accountType),
              Wrap(
                spacing: CentSpace.sm,
                children: [
                  for (final type in AccountType.values)
                    CentChip(
                      label: accountTypeLabel(l10n, type),
                      selected: type == _type,
                      onTap: () => setState(() => _type = type),
                    ),
                ],
              ),
              label(l10n.currency),
              CentCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  enabled: !_editing,
                  title: Text(
                    _currency.name,
                    style: CentType.body.copyWith(color: c.ink),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currency.code,
                        style: CentType.body.copyWith(color: c.mute),
                      ),
                      if (!_editing)
                        Icon(CentIcons.forward, size: 18, color: c.mute),
                    ],
                  ),
                  onTap: () async {
                    final picked = await pickCurrency(
                      context,
                      selected: _currency,
                    );
                    if (picked != null) setState(() => _currency = picked);
                  },
                ),
              ),
              label(l10n.startingBalance),
              AmountField(
                controller: _balance,
                currency: _currency,
                allowNegative: true,
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.startingBalanceHint,
                  style: CentType.footnote.copyWith(color: c.mute),
                ),
              ),
              const SizedBox(height: 20),
              CentCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: CentSpace.lg,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.includeInNetWorth,
                        style: CentType.body.copyWith(color: c.ink),
                      ),
                    ),
                    CupertinoSwitch(
                      value: _includeInNetWorth,
                      activeTrackColor: c.primary,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _includeInNetWorth = v);
                      },
                    ),
                  ],
                ),
              ),
              if (_editing) ...[
                const SizedBox(height: CentSpace.xxl),
                CentButton(
                  label: l10n.archiveAccount,
                  style: CentButtonStyle.destructive,
                  expand: true,
                  onPressed: () => unawaited(_archive()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
