import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../../l10n/app_localizations.dart';
import 'entry_providers.dart';

final _merchantProvider = FutureProvider.autoDispose
    .family<({int count, int totalMinor}), (String, String, DateTime)>(
      (ref, key) => ref
          .watch(transactionsRepositoryProvider)
          .merchantMonth(key.$1, key.$2, key.$3),
    );

class EntryDetailScreen extends ConsumerWidget {
  const EntryDetailScreen({
    super.key,
    required this.id,
    required this.backLabel,
  });

  final int id;
  final String backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(entryProvider(id)).value;

    return InlineScaffold(
      backLabel: backLabel,
      bottom: view == null
          ? null
          : CentButton(
              label: l10n.deleteTransaction,
              style: CentButtonStyle.destructive,
              expand: true,
              onPressed: () => unawaited(_confirmDelete(context, ref, view)),
            ),
      body: view == null ? const SizedBox.shrink() : _Body(view: view),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EntryView view,
  ) async {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    unawaited(HapticFeedback.mediumImpact());
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        message: Text(
          l10n.deleteConfirm(view.entry.title, formatMoney(view.amount)),
          style: CentType.footnote.copyWith(color: c.mute),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text(l10n.deleteTransaction),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(transactionsRepositoryProvider).delete(view.entry.id);
    if (context.mounted) context.pop();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.view});

  final EntryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final entry = view.entry;
    final isTransfer = entry.kind == TransactionKind.transfer;
    final category = view.category;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    final merchant = entry.kind == TransactionKind.expense
        ? ref
              .watch(
                _merchantProvider((
                  entry.title,
                  entry.currency,
                  entry.occurredAt,
                )),
              )
              .value
        : null;

    final rows = <(String, String)>[
      if (!isTransfer) (l10n.detailCategory, category?.name ?? '—'),
      (l10n.detailAccount, view.account.name),
      (l10n.detailDate, fullDate(context, entry.occurredAt)),
      (
        l10n.detailRepeat,
        entry.recurringRuleId == null ? l10n.repeatNever : l10n.repeatMonthly,
      ),
      if (entry.note != null && entry.note!.isNotEmpty)
        (l10n.detailNote, entry.note!),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(margin, CentSpace.lg, margin, 40),
      children: [
        Center(
          child: CategoryTile(
            icon: isTransfer
                ? CentIcons.transfer
                : CentIcons.named(category?.icon ?? 'receipt'),
            tint: isTransfer
                ? CentTint.neutral
                : CentTint.parse(category?.tint ?? 'neutral'),
            size: 56,
          ),
        ),
        const SizedBox(height: CentSpace.md),
        Text(
          entry.title,
          textAlign: TextAlign.center,
          style: CentType.title2.copyWith(color: c.ink),
        ),
        const SizedBox(height: CentSpace.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatMoney(
              view.amount,
              sign: isTransfer ? SignDisplay.auto : SignDisplay.always,
            ),
            style: CentType.displayHero.copyWith(
              color: entry.kind == TransactionKind.income ? c.positive : c.ink,
            ),
          ),
        ),
        const SizedBox(height: CentSpace.xxl - 4),
        CentGroup(
          children: [
            for (var i = 0; i < rows.length; i++)
              _InfoRow(
                label: rows[i].$1,
                value: rows[i].$2,
                showDivider: i < rows.length - 1,
              ),
          ],
        ),
        if (merchant != null && merchant.count > 1) ...[
          const SizedBox(height: CentSpace.lg),
          CentCard(
            color: c.cream,
            child: Text(
              l10n.merchantInsight(
                formatMoney(
                  Money(merchant.totalMinor.abs(), Currency.of(entry.currency)),
                ),
                entry.title,
                merchant.count,
              ),
              style: CentType.callout.copyWith(color: c.ink),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CentSpace.lg,
              vertical: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CentType.body.copyWith(color: c.mute)),
                const SizedBox(width: CentSpace.lg),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: CentType.body.copyWith(color: c.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const InsetDivider(indent: CentSpace.lg),
      ],
    );
  }
}
