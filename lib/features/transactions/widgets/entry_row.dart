import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/format/dates.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/cent_icons.dart';
import '../../../core/theme/cent_theme.dart';
import '../../../core/theme/cent_tokens.dart';
import '../../../core/theme/cent_typography.dart';
import '../../../core/widgets/list_parts.dart';
import '../../../data/transactions_repository.dart';
import '../../../l10n/app_localizations.dart';

enum EntrySubtitle {
  /// Category and time, for lists already grouped by day.
  time,

  /// Category and day, for flat lists such as search results.
  date,
}

class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.view,
    required this.now,
    required this.onTap,
    this.subtitle = EntrySubtitle.time,
    this.showDivider = true,
  });

  final EntryView view;
  final DateTime now;
  final VoidCallback onTap;
  final EntrySubtitle subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final entry = view.entry;
    final isTransfer = entry.kind == TransactionKind.transfer;
    final category = view.category;

    final label = isTransfer
        ? '${l10n.transfer} · ${view.account.name}'
        : category?.name ?? view.account.name;
    final when = switch (subtitle) {
      EntrySubtitle.time => timeLabel(context, entry.occurredAt),
      EntrySubtitle.date => dayLabel(context, entry.occurredAt, now),
    };
    final amountText = formatMoney(
      view.amount,
      sign: isTransfer ? SignDisplay.auto : SignDisplay.always,
    );
    final amountColor = entry.kind == TransactionKind.income
        ? c.positive
        : c.ink;

    return Semantics(
      button: true,
      label: '${entry.title}, $label, $when, $amountText',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: c.hairline.withValues(alpha: 0.6),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CentSize.row),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CentSpace.lg,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CategoryTile(
                      icon: isTransfer
                          ? CentIcons.transfer
                          : CentIcons.named(category?.icon ?? 'receipt'),
                      tint: isTransfer
                          ? CentTint.neutral
                          : CentTint.parse(category?.tint ?? 'neutral'),
                    ),
                    const SizedBox(width: CentSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CentType.body.copyWith(color: c.ink),
                          ),
                          Text(
                            '$label · $when',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CentType.subheadline.copyWith(color: c.mute),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: CentSpace.md),
                    Text(
                      amountText,
                      style: CentType.bodyTabular.copyWith(color: amountColor),
                    ),
                  ],
                ),
              ),
            ),
            if (showDivider) const InsetDivider(),
          ],
        ),
      ),
    );
  }
}
