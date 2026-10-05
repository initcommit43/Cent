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
import '../../data/recurrence.dart';
import '../../data/recurring_repository.dart';
import '../../l10n/app_localizations.dart';
import 'plan_format.dart';

final _ruleProvider = StreamProvider.autoDispose.family<RuleView?, int>(
  (ref, id) => ref.watch(recurringRepositoryProvider).watchOne(id),
);

final _historyProvider = StreamProvider.autoDispose
    .family<List<LedgerEntry>, int>(
      (ref, id) => ref.watch(recurringRepositoryProvider).watchHistory(id),
    );

class RecurringDetailScreen extends ConsumerWidget {
  const RecurringDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(_ruleProvider(id)).value;
    final history = ref.watch(_historyProvider(id)).value ?? const [];
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    ref.listen(_ruleProvider(id), (previous, next) {
      if (previous?.value != null && next.hasValue && next.value == null) {
        context.pop();
      }
    });

    if (view == null) return const InlineScaffold(body: SizedBox.shrink());
    final rule = view.rule;
    final currency = Currency.of(rule.currency);
    final yearly = Money(
      monthlyEquivalentMinor(rule.amountMinor, rule.frequency, rule.interval) *
          12,
      currency,
    );
    final paid = Money(
      history.fold<int>(0, (sum, e) => sum + e.amountMinor.abs()),
      currency,
    );

    final rows = [
      (
        l10n.nextPayment,
        rule.paused ? l10n.paused : dayLabel(context, rule.nextDue, now),
      ),
      (l10n.repeats, frequencyLabel(l10n, rule.frequency)),
      (l10n.detailAccount, view.account.name),
      if (view.category != null) (l10n.detailCategory, view.category!.name),
    ];

    return InlineScaffold(
      backLabel: l10n.tabPlan,
      bottom: Row(
        children: [
          Expanded(
            child: CentButton(
              label: rule.paused ? l10n.resume : l10n.pause,
              icon: rule.paused ? CentIcons.play : CentIcons.pause,
              style: CentButtonStyle.secondary,
              expand: true,
              onPressed: () {
                HapticFeedback.selectionClick();
                unawaited(
                  ref
                      .read(recurringRepositoryProvider)
                      .setPaused(rule.id, paused: !rule.paused),
                );
              },
            ),
          ),
          const SizedBox(width: CentSpace.md),
          Expanded(
            child: CentButton(
              label: l10n.delete,
              style: CentButtonStyle.destructive,
              expand: true,
              onPressed: () => unawaited(_confirmDelete(context, ref, rule)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          Center(
            child: CategoryTile(
              icon: CentIcons.named(view.category?.icon ?? 'receipt'),
              tint: CentTint.parse(view.category?.tint ?? 'neutral'),
              size: 56,
            ),
          ),
          const SizedBox(height: CentSpace.md),
          Text(
            rule.title,
            textAlign: TextAlign.center,
            style: CentType.title2.copyWith(color: c.ink),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(view.amount, sign: SignDisplay.always),
              style: CentType.displayHero.copyWith(
                color: rule.kind == TransactionKind.income ? c.positive : c.ink,
              ),
            ),
          ),
          const SizedBox(height: CentSpace.xl),
          CentGroup(
            children: [
              for (var i = 0; i < rows.length; i++)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CentSpace.lg,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            rows[i].$1,
                            style: CentType.body.copyWith(color: c.mute),
                          ),
                          const Spacer(),
                          Text(
                            rows[i].$2,
                            style: CentType.body.copyWith(color: c.ink),
                          ),
                        ],
                      ),
                    ),
                    if (i < rows.length - 1)
                      const InsetDivider(indent: CentSpace.lg),
                  ],
                ),
            ],
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: CentSpace.lg),
            CentCard(
              color: c.cream,
              child: Text(
                l10n.yearlyCostPaid(
                  formatMoney(yearly),
                  formatMoney(paid),
                  shortDate(context, history.last.occurredAt),
                ),
                style: CentType.callout.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: CentSpace.xl),
            SectionHeader(title: l10n.history),
            CentGroup(
              children: [
                for (var i = 0; i < history.length && i < 12; i++)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CentSpace.lg,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              dayLabel(context, history[i].occurredAt, now),
                              style: CentType.body.copyWith(color: c.ink),
                            ),
                            const Spacer(),
                            Text(
                              formatMoney(
                                Money(history[i].amountMinor, currency),
                                sign: SignDisplay.always,
                              ),
                              style: CentType.bodyTabular.copyWith(
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < history.length - 1 && i < 11)
                        const InsetDivider(indent: CentSpace.lg),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RecurringRule rule,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        message: Text(l10n.deleteRecurringConfirm(rule.title)),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(recurringRepositoryProvider).delete(rule.id);
    }
  }
}
