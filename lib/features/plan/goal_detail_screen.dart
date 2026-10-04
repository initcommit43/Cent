import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/amount_field.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/sheet.dart';
import '../../data/goals_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'goal_sheet.dart';

final _goalProvider = StreamProvider.autoDispose.family<GoalProgress?, int>(
  (ref, id) => ref.watch(goalsRepositoryProvider).watchOne(id),
);

final _contributionsProvider = StreamProvider.autoDispose
    .family<List<GoalContribution>, int>(
      (ref, id) => ref.watch(goalsRepositoryProvider).watchContributions(id),
    );

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(_goalProvider(id)).value;
    final contributions =
        ref.watch(_contributionsProvider(id)).value ?? const [];
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final locale = Localizations.localeOf(context).toString();

    ref.listen(_goalProvider(id), (previous, next) {
      if (previous?.value != null && next.hasValue && next.value == null) {
        context.pop();
      }
    });

    if (progress == null) return const InlineScaffold(body: SizedBox.shrink());
    final goal = progress.goal;
    final monthly = progress.monthlyNeeded(now);

    return InlineScaffold(
      title: goal.name,
      backLabel: l10n.tabPlan,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => unawaited(showGoalSheet(context, existing: progress)),
        child: Text(l10n.edit),
      ),
      bottom: progress.isComplete
          ? null
          : CentButton(
              label: l10n.addMoney,
              icon: CentIcons.add,
              expand: true,
              onPressed: () => unawaited(_showAddMoney(context, progress)),
            ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          Center(
            child: CategoryTile(
              icon: CentIcons.named(goal.icon),
              tint: CentTint.parse(goal.tint),
              size: 56,
            ),
          ),
          const SizedBox(height: CentSpace.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(progress.saved),
              style: CentType.displayHero.copyWith(color: c.ink),
            ),
          ),
          Text(
            progress.isComplete
                ? l10n.goalReached
                : l10n.percentSaved(
                    (progress.ratio * 100).floor(),
                    formatMoney(progress.remaining),
                  ),
            textAlign: TextAlign.center,
            style: CentType.subheadline.copyWith(
              color: progress.isComplete ? c.positive : c.mute,
            ),
          ),
          const SizedBox(height: CentSpace.lg),
          CentProgressBar(value: progress.ratio, color: c.accentPatina),
          const SizedBox(height: CentSpace.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatMoney(progress.target),
              style: CentType.caption1.copyWith(color: c.mute),
            ),
          ),
          if (!progress.isComplete) ...[
            const SizedBox(height: CentSpace.lg),
            CentCard(
              color: c.cream,
              child: Text(
                monthly != null && goal.targetDate != null
                    ? l10n.goalMonthlyByDate(
                        formatMoney(monthly),
                        DateFormat.yMMMM(locale).format(goal.targetDate!),
                      )
                    : l10n.goalNoDeadline,
                style: CentType.callout.copyWith(color: c.ink),
              ),
            ),
          ],
          if (contributions.isNotEmpty) ...[
            const SizedBox(height: CentSpace.xl),
            SectionHeader(
              title: l10n.contributions,
              trailing: formatMoney(progress.saved),
            ),
            CentGroup(
              children: [
                for (var i = 0; i < contributions.length; i++)
                  _ContributionRow(
                    contribution: contributions[i],
                    currency: progress.currency,
                    showDivider: i < contributions.length - 1,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.currency,
    required this.showDivider,
  });

  final GoalContribution contribution;
  final Currency currency;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CentSpace.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contribution.note ?? l10n.addMoney,
                      style: CentType.body.copyWith(color: c.ink),
                    ),
                    Text(
                      shortDate(context, contribution.occurredAt),
                      style: CentType.subheadline.copyWith(color: c.mute),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(
                  Money(contribution.amountMinor, currency),
                  sign: SignDisplay.always,
                ),
                style: CentType.bodyTabular.copyWith(color: c.positive),
              ),
            ],
          ),
        ),
        if (showDivider) const InsetDivider(indent: CentSpace.lg),
      ],
    );
  }
}

Future<void> _showAddMoney(BuildContext context, GoalProgress progress) =>
    showCentSheet<void>(
      context,
      builder: (_) => _AddMoneySheet(progress: progress),
    );

class _AddMoneySheet extends ConsumerStatefulWidget {
  const _AddMoneySheet({required this.progress});

  final GoalProgress progress;

  @override
  ConsumerState<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends ConsumerState<_AddMoneySheet> {
  final _amount = TextEditingController();

  int get _minor =>
      parseAmountMinor(_amount.text, widget.progress.currency) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(goalsRepositoryProvider)
        .contribute(
          widget.progress.goal.id,
          Money(_minor, widget.progress.currency),
          at: ref.read(clockProvider)(),
        );
    unawaited(HapticFeedback.heavyImpact());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final amount = Money(_minor, widget.progress.currency);
    final after = widget.progress.saved + amount;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: l10n.addMoneyTo(widget.progress.goal.name),
              cancelLabel: l10n.cancel,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AmountField(
                    controller: _amount,
                    currency: widget.progress.currency,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: CentSpace.sm),
                  Text(
                    l10n.afterThisYouHave(
                      formatMoney(after),
                      formatMoney(widget.progress.target),
                    ),
                    textAlign: TextAlign.center,
                    style: CentType.footnote.copyWith(color: c.mute),
                  ),
                  const SizedBox(height: CentSpace.lg),
                  CentButton(
                    label: l10n.addAmount(formatMoney(amount)),
                    expand: true,
                    onPressed: _minor > 0 ? () => unawaited(_save()) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
