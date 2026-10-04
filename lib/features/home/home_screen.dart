import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dates.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/router/routes.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/pressable.dart';
import '../../data/accounts_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_style.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../transactions/widgets/entry_row.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(homeSummaryProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final recent = ref.watch(recentEntriesProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    Widget section(Widget child) => SliverPadding(
      padding: EdgeInsets.fromLTRB(margin, CentSpace.xxl - 4, margin, 0),
      sliver: SliverToBoxAdapter(child: child),
    );

    return LargeTitleScaffold(
      title: l10n.tabHome,
      band: true,
      leadOverlap: 96,
      actions: [
        CentIconButton(
          icon: CentIcons.settings,
          label: l10n.settings,
          onPressed: () => context.push(Routes.settings),
        ),
      ],
      lead: summary == null
          ? const SizedBox(height: 180)
          : _BalanceCard(summary: summary),
      slivers: [
        if (accounts.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: CentSpace.xxl - 4),
            sliver: SliverToBoxAdapter(
              child: _AccountsStrip(accounts: accounts, margin: margin),
            ),
          ),
        if (summary != null) section(_MonthCard(summary: summary, now: now)),
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: l10n.recent,
                trailing: recent.isEmpty ? null : l10n.seeAll,
                onTrailingTap: () => context.go(Routes.activity),
              ),
              if (recent.isEmpty)
                CentCard(
                  child: Text(
                    l10n.noTransactionsYet,
                    style: CentType.body.copyWith(color: context.colors.mute),
                  ),
                )
              else
                CentGroup(
                  children: [
                    for (var i = 0; i < recent.length; i++)
                      EntryRow(
                        view: recent[i],
                        now: now,
                        subtitle: EntrySubtitle.date,
                        showDivider: i < recent.length - 1,
                        onTap: () =>
                            context.push(Routes.homeEntry(recent[i].entry.id)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final net = summary.month.net;
    final onHero = c.onPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(CentRadius.xxl),
        border: Border.all(color: c.heroBorder),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? const [
                BoxShadow(
                  color: Color(0x1A10302B),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x0A10302B),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.totalBalance,
            style: CentType.subheadline.copyWith(
              color: onHero.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 6),
          // Scales down long balances instead of clipping them.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(summary.totalBalance),
              style: CentType.displayHero.copyWith(color: onHero),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                net.isNegative ? CentIcons.down : CentIcons.up,
                size: 16,
                color: onHero.withValues(alpha: 0.78),
              ),
              const SizedBox(width: 4),
              Text(
                l10n.netThisMonth(formatMoney(net, sign: SignDisplay.always)),
                style: CentType.subheadlineTabular.copyWith(
                  color: onHero.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CentButton(
            label: l10n.addTransaction,
            icon: CentIcons.add,
            style: CentButtonStyle.onDark,
            onPressed: () => unawaited(showAddTransaction(context)),
          ),
        ],
      ),
    );
  }
}

class _AccountsStrip extends StatelessWidget {
  const _AccountsStrip({required this.accounts, required this.margin});

  final List<AccountWithBalance> accounts;
  final double margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: SectionHeader(
            title: l10n.accounts,
            trailing: l10n.seeAll,
            onTrailingTap: () => context.push(Routes.accounts),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: margin),
            clipBehavior: Clip.none,
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final a = accounts[i];
              return Pressable(
                semanticLabel: '${a.account.name}, ${formatMoney(a.balance)}',
                onTap: () => context.push(Routes.account(a.account.id)),
                child: SizedBox(
                  width: 152,
                  child: CentCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CategoryTile(
                          icon: accountIcon(a.account.type),
                          tint: accountTint(a.account.type),
                          size: 32,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CentType.footnote.copyWith(color: c.mute),
                            ),
                            Text(
                              formatMoney(a.balance),
                              maxLines: 1,
                              style: CentType.bodyTabular.copyWith(
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary, required this.now});

  final HomeSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final spent = summary.month.spent;
    final budget = summary.monthBudget;
    final daysLeft = daysLeftInMonth(now);

    final (String footer, Color barColor, double ratio) = switch (budget) {
      null => (l10n.noBudgetSpent, c.accentPatina, 0.0),
      final b when spent > b => (
        l10n.overBudgetBy(formatMoney(spent - b)),
        c.negative,
        1.0,
      ),
      final b => (
        l10n.leftPerDay(
          formatMoney(b - spent),
          formatMoney(
            Money(((b - spent).minor / daysLeft).round(), b.currency),
          ),
        ),
        spent.ratioOf(b) >= 0.9 ? c.warning : c.accentPatina,
        spent.ratioOf(b),
      ),
    };

    return CentCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.monthSpending(monthName(context, now)),
                  style: CentType.headline.copyWith(color: c.ink),
                ),
              ),
              Text(
                l10n.daysLeft(daysLeft),
                style: CentType.footnote.copyWith(color: c.mute),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                formatMoney(spent),
                style: CentType.title1.copyWith(
                  color: c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (budget != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    l10n.ofAmount(formatMoney(budget)),
                    style: CentType.subheadlineTabular.copyWith(color: c.mute),
                  ),
                ),
            ],
          ),
          if (budget != null) ...[
            const SizedBox(height: 10),
            CentProgressBar(value: ratio, color: barColor),
          ],
          const SizedBox(height: 10),
          Text(
            footer,
            style: CentType.footnote.copyWith(
              color: budget != null && spent > budget
                  ? c.negative
                  : c.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
