import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/cent_text_field.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_style.dart';
import '../activity/activity_providers.dart';
import '../common/pickers.dart';
import 'add_transaction_controller.dart';
import 'amount_input.dart';

/// Opens the add flow, or the edit flow when [editId] is given. Resolves to
/// true when something was saved.
Future<bool> showAddTransaction(
  BuildContext context, {
  int? editId,
  TransactionKind kind = TransactionKind.expense,
  int? accountId,
}) async {
  final saved = await showCentSheet<bool>(
    context,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _AddTransactionSheet(
        editId: editId,
        kind: kind,
        accountId: accountId,
      ),
    ),
  );
  return saved ?? false;
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet({required this.kind, this.editId, this.accountId});

  final int? editId;
  final TransactionKind kind;
  final int? accountId;

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  late bool _onDetails = widget.editId != null;
  final _title = TextEditingController();
  final _note = TextEditingController();

  AddTransactionController get _controller =>
      ref.read(addTransactionControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (widget.editId == null) {
      await _controller.startNew(
        kind: widget.kind,
        accountId: widget.accountId,
      );
    } else {
      await _controller.startEdit(widget.editId!);
      final draft = ref.read(addTransactionControllerProvider)!;
      _title.text = draft.title;
      _note.text = draft.note;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _controller.save();
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(addTransactionControllerProvider);
    if (draft == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      child: _onDetails
          ? _DetailsStep(
              key: const ValueKey('details'),
              draft: draft,
              title: _title,
              note: _note,
              onBack: widget.editId == null
                  ? () => setState(() => _onDetails = false)
                  : null,
              onEditAmount: () => setState(() => _onDetails = false),
              onSave: _save,
            )
          : _AmountStep(
              key: const ValueKey('amount'),
              draft: draft,
              onContinue: () => setState(() => _onDetails = true),
            ),
    );
  }
}

class _AmountStep extends ConsumerWidget {
  const _AmountStep({super.key, required this.draft, required this.onContinue});

  final TransactionDraft draft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(addTransactionControllerProvider.notifier);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final account = accounts
        .where((a) => a.account.id == draft.accountId)
        .firstOrNull;
    final currency = controller.currency;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SheetHeader(
            title: draft.editingId == null
                ? l10n.newTransaction
                : l10n.editTransaction,
            cancelLabel: l10n.cancel,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(margin, 12, margin, 0),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<TransactionKind>(
                groupValue: draft.kind,
                backgroundColor: c.hairline,
                thumbColor: c.canvas,
                children: {
                  for (final (kind, label) in [
                    (TransactionKind.expense, l10n.expense),
                    (TransactionKind.income, l10n.income),
                    (TransactionKind.transfer, l10n.transfer),
                  ])
                    kind: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        style: CentType.subheadline.copyWith(color: c.ink),
                      ),
                    ),
                },
                onValueChanged: (kind) {
                  if (kind == null) return;
                  HapticFeedback.selectionClick();
                  controller.setKind(kind);
                },
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: margin),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Semantics(
                      liveRegion: true,
                      label: formatMoney(draft.amount.toMoney(currency)),
                      excludeSemantics: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            currency.symbol,
                            style: CentType.title2.copyWith(color: c.mute),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            draft.amount.display,
                            style: CentType.displayHero.copyWith(
                              color: draft.amount.isZero ? c.mute : c.ink,
                              fontSize: 64,
                              height: 1.06,
                              letterSpacing: -1.6,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 52,
                            margin: const EdgeInsets.only(left: 4),
                            color: c.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: CentSpace.lg),
                if (account != null)
                  _AccountPill(
                    account: account.account,
                    label: draft.isTransfer
                        ? l10n.fromAccountNamed(account.account.name)
                        : '${account.account.name} · ${currency.code}',
                    onTap: () async {
                      final id = await pickAccount(
                        context,
                        selectedId: draft.accountId,
                      );
                      if (id != null) controller.setAccount(id);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: _Keypad(
              decimals: currency.decimals > 0,
              onKey: controller.pressKey,
              onDelete: controller.deleteKey,
            ),
          ),
          const SizedBox(height: CentSpace.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: CentButton(
              label: l10n.continueAction,
              expand: true,
              onPressed: controller.canContinue ? onContinue : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({
    required this.account,
    required this.label,
    required this.onTap,
  });

  final Account account;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(
            color: c.canvasSoft,
            borderRadius: BorderRadius.circular(CentRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryTile(
                icon: accountIcon(account.type),
                tint: accountTint(account.type),
                size: 24,
              ),
              const SizedBox(width: CentSpace.sm),
              Text(label, style: CentType.subheadline.copyWith(color: c.ink)),
              const SizedBox(width: 4),
              Icon(CentIcons.chevronDown, size: 16, color: c.mute),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.decimals,
    required this.onKey,
    required this.onDelete,
  });

  final bool decimals;
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [AmountInput.decimalKey, '0', 'del'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final key in row) ...[
                  Expanded(
                    child: switch (key) {
                      'del' => _Key(
                        semantic: l10n.deleteKey,
                        onTap: onDelete,
                        child: Icon(
                          CentIcons.backspace,
                          size: 22,
                          color: context.colors.ink,
                        ),
                      ),
                      AmountInput.decimalKey when !decimals =>
                        const SizedBox.shrink(),
                      _ => _Key(
                        semantic: key == AmountInput.decimalKey
                            ? l10n.decimalPoint
                            : key,
                        onTap: () => onKey(key),
                        child: Text(
                          key,
                          style: CentType.title2.copyWith(
                            color: context.colors.ink,
                            fontWeight: FontWeight.w400,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    },
                  ),
                  if (key != row.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.semantic,
    required this.onTap,
    required this.child,
  });

  final String semantic;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: Material(
        color: context.colors.canvasSoft,
        borderRadius: BorderRadius.circular(CentRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(CentRadius.lg),
          highlightColor: context.colors.hairline,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: SizedBox(height: 52, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep({
    super.key,
    required this.draft,
    required this.title,
    required this.note,
    required this.onBack,
    required this.onEditAmount,
    required this.onSave,
  });

  final TransactionDraft draft;
  final TextEditingController title;
  final TextEditingController note;

  /// Null when editing, where there is no amount step to return to.
  final VoidCallback? onBack;
  final VoidCallback onEditAmount;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(addTransactionControllerProvider.notifier);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final amount = controller.amount;

    String accountName(int? id) =>
        accounts.where((a) => a.account.id == id).firstOrNull?.account.name ??
        '—';
    final category = categories
        .where((cat) => cat.id == draft.categoryId)
        .firstOrNull;

    final heading = switch ((draft.editingId, draft.kind)) {
      (final int _, _) => l10n.editTransaction,
      (_, TransactionKind.expense) => l10n.newExpense,
      (_, TransactionKind.income) => l10n.newIncome,
      (_, TransactionKind.transfer) => l10n.newTransfer,
    };
    final saveLabel = switch ((draft.editingId, draft.kind)) {
      (final int _, _) => l10n.saveChanges,
      (_, TransactionKind.expense) => l10n.saveExpense,
      (_, TransactionKind.income) => l10n.saveIncome,
      (_, TransactionKind.transfer) => l10n.saveTransfer(formatMoney(amount)),
    };
    final signed = switch (draft.kind) {
      TransactionKind.expense => -amount,
      _ => amount,
    };

    return ColoredBox(
      color: c.canvasSoft,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            SheetHeader(
              title: heading,
              cancelLabel: onBack == null ? l10n.cancel : l10n.back,
              onCancel: onBack,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 24),
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditAmount,
                    child: Column(
                      children: [
                        Text(
                          formatMoney(
                            signed,
                            sign: draft.isTransfer
                                ? SignDisplay.auto
                                : SignDisplay.always,
                          ),
                          style: CentType.title1.copyWith(
                            color: draft.kind == TransactionKind.income
                                ? c.positive
                                : c.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          l10n.fromAccountNamed(accountName(draft.accountId)),
                          style: CentType.subheadline.copyWith(color: c.mute),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CentSpace.xl),
                  CentTextField(
                    label: l10n.fieldName,
                    hint: draft.isTransfer ? null : l10n.fieldNameHint,
                    controller: title,
                    autofocus: draft.editingId == null && !draft.isTransfer,
                    onChanged: controller.setTitle,
                  ),
                  const SizedBox(height: 20),
                  CentGroup(
                    children: [
                      if (!draft.isTransfer)
                        _NavRow(
                          label: l10n.category,
                          value: category?.name ?? '—',
                          leading: category == null
                              ? null
                              : CategoryTile(
                                  icon: CentIcons.named(category.icon),
                                  tint: CentTint.parse(category.tint),
                                  size: 28,
                                ),
                          onTap: () async {
                            final id = await pickCategory(
                              context,
                              kind: draft.kind == TransactionKind.income
                                  ? CategoryKind.income
                                  : CategoryKind.expense,
                              selectedId: draft.categoryId,
                            );
                            if (id != null) controller.setCategory(id);
                          },
                        ),
                      _NavRow(
                        label: draft.isTransfer
                            ? l10n.fromAccount
                            : l10n.detailAccount,
                        value: accountName(draft.accountId),
                        onTap: () async {
                          final id = await pickAccount(
                            context,
                            selectedId: draft.accountId,
                          );
                          if (id != null) controller.setAccount(id);
                        },
                      ),
                      if (draft.isTransfer)
                        _NavRow(
                          label: l10n.toAccount,
                          value: accountName(draft.toAccountId),
                          onTap: () async {
                            final id = await pickAccount(
                              context,
                              selectedId: draft.toAccountId,
                              excludeId: draft.accountId,
                            );
                            if (id != null) controller.setToAccount(id);
                          },
                        ),
                      if (!draft.isTransfer && draft.editingId == null)
                        _NavRow(
                          label: l10n.detailRepeat,
                          value: switch (draft.repeat) {
                            null => l10n.repeatNever,
                            Frequency.weekly => l10n.repeatWeekly,
                            Frequency.monthly => l10n.repeatMonthly,
                            Frequency.yearly => l10n.repeatYearly,
                          },
                          onTap: () async {
                            final picked = await _pickRepeat(context);
                            if (picked != null) {
                              controller.setRepeat(picked.frequency);
                            }
                          },
                        ),
                      _NavRow(
                        label: l10n.detailDate,
                        value:
                            '${dayLabel(context, draft.occurredAt, ref.watch(clockProvider)())}'
                            ' · ${timeLabel(context, draft.occurredAt)}',
                        showDivider: false,
                        onTap: () async {
                          final at = await pickDateTime(
                            context,
                            draft.occurredAt,
                          );
                          if (at != null) controller.setDate(at);
                        },
                      ),
                    ],
                  ),
                  if (draft.isTransfer) _Conversion(draft: draft),
                  const SizedBox(height: 20),
                  CentTextField(
                    label: l10n.fieldNote,
                    hint: l10n.fieldNoteHint,
                    controller: note,
                    textInputAction: TextInputAction.done,
                    onChanged: controller.setNote,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: CentButton(
                label: saveLabel,
                expand: true,
                onPressed: controller.canSave
                    ? () => unawaited(onSave())
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows what a cross-currency transfer arrives as.
class _Conversion extends ConsumerWidget {
  const _Conversion({required this.draft});

  final TransactionDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(addTransactionControllerProvider.notifier);
    if (draft.toAccountId == null ||
        controller.currencyOf(draft.toAccountId!) == controller.currency) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Money?>(
      future: controller.received(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 40);
        }
        final received = snapshot.data;
        return Padding(
          padding: const EdgeInsets.only(top: CentSpace.md),
          child: CentCard(
            color: c.cream,
            padding: const EdgeInsets.symmetric(
              horizontal: CentSpace.lg,
              vertical: CentSpace.md,
            ),
            child: Text(
              received == null
                  ? l10n.noRateAvailable
                  : l10n.arrivesAs(formatMoney(received)),
              style: CentType.subheadlineTabular.copyWith(color: c.ink),
            ),
          ),
        );
      },
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.only(left: CentSpace.lg, right: 12),
              child: Row(
                children: [
                  Text(label, style: CentType.body.copyWith(color: c.mute)),
                  const Spacer(),
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: CentSpace.sm),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CentType.body.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(CentIcons.forward, size: 18, color: c.mute),
                ],
              ),
            ),
          ),
          if (showDivider) const InsetDivider(indent: CentSpace.lg),
        ],
      ),
    );
  }
}

/// Wraps the choice so "Never" (null) is distinguishable from dismissing.
class _RepeatChoice {
  const _RepeatChoice(this.frequency);

  final Frequency? frequency;
}

Future<_RepeatChoice?> _pickRepeat(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showCupertinoModalPopup<_RepeatChoice>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(l10n.detailRepeat),
      actions: [
        for (final (frequency, label) in [
          (null, l10n.repeatNever),
          (Frequency.weekly, l10n.repeatWeekly),
          (Frequency.monthly, l10n.repeatMonthly),
          (Frequency.yearly, l10n.repeatYearly),
        ])
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(sheetContext).pop(_RepeatChoice(frequency)),
            child: Text(label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(l10n.cancel),
      ),
    ),
  );
}
