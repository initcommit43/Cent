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
import '../../core/router/routes.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/charts/line_chart.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/accounts_repository.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../../l10n/app_localizations.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../transactions/entry_math.dart';
import '../transactions/widgets/entry_row.dart';
import 'account_sheet.dart';
import 'account_style.dart';

enum _Period { days30, months3, year }

final _accountProvider = StreamProvider.autoDispose
    .family<AccountWithBalance, int>(
      (ref, id) => ref.watch(accountsRepositoryProvider).watch(id),
    );

final _accountEntriesProvider = StreamProvider.autoDispose
    .family<List<EntryView>, int>(
      (ref, id) => ref
          .watch(transactionsRepositoryProvider)
          .watchForAccount(id, limit: 100),
    );

final _balancesProvider = StreamProvider.autoDispose
    .family<List<int>, (int, _Period)>((ref, key) {
      final today = ref.watch(clockProvider)();
      final from = switch (key.$2) {
        _Period.days30 => today.subtract(const Duration(days: 29)),
        _Period.months3 => DateTime(today.year, today.month - 3, today.day),
        _Period.year => DateTime(today.year - 1, today.month, today.day),
      };
      return ref
          .watch(accountsRepositoryProvider)
          .watchDailyBalances(key.$1, from, today);
    });

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  var _period = _Period.days30;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final item = ref.watch(_accountProvider(widget.id)).value;
    final entries = ref.watch(_accountEntriesProvider(widget.id)).value;
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    // Archiving from the edit sheet removes the account from view.
    ref.listen(_accountProvider(widget.id), (_, next) {
      if (next.value?.account.archived ?? false) context.pop();
    });

    if (item == null) return const InlineScaffold(body: SizedBox.shrink());
    final account = item.account;

    return InlineScaffold(
      title: account.name,
      backLabel: l10n.accounts,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => unawaited(showAccountSheet(context, account: account)),
        child: Text(l10n.edit),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          Text(
            '${accountTypeLabel(l10n, account.type)} · ${account.currency}',
            textAlign: TextAlign.center,
            style: CentType.subheadline.copyWith(color: c.mute),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(item.balance),
              style: CentType.displayHero.copyWith(color: c.ink),
            ),
          ),
          const SizedBox(height: CentSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CentButton(
                label: l10n.add,
                icon: CentIcons.add,
                style: CentButtonStyle.compact,
                onPressed: () => unawaited(
                  showAddTransaction(context, accountId: account.id),
                ),
              ),
              const SizedBox(width: 10),
              CentButton(
                label: l10n.transfer,
                icon: CentIcons.transfer,
                style: CentButtonStyle.compactSecondary,
                onPressed: () => unawaited(
                  showAddTransaction(
                    context,
                    kind: TransactionKind.transfer,
                    accountId: account.id,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CentSpace.xl),
          _BalanceChart(
            accountId: account.id,
            currency: Currency.of(account.currency),
            period: _period,
            onPeriod: (p) => setState(() => _period = p),
            now: now,
          ),
          const SizedBox(height: CentSpace.xl),
          if (entries != null && entries.isEmpty)
            CentCard(
              child: Text(
                l10n.noAccountTransactions,
                style: CentType.body.copyWith(color: c.mute),
              ),
            ),
          if (entries != null)
            for (final (day, items) in groupByDay(entries))
              Padding(
                padding: const EdgeInsets.only(bottom: CentSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: dayLabel(context, day, now)),
                    CentGroup(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          EntryRow(
                            view: items[i],
                            now: now,
                            showDivider: i < items.length - 1,
                            onTap: () => context.push(
                              Routes.homeEntry(items[i].entry.id),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BalanceChart extends ConsumerWidget {
  const _BalanceChart({
    required this.accountId,
    required this.currency,
    required this.period,
    required this.onPeriod,
    required this.now,
  });

  final int accountId;
  final Currency currency;
  final _Period period;
  final ValueChanged<_Period> onPeriod;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final balances = ref.watch(_balancesProvider((accountId, period))).value;
    final labels = {
      _Period.days30: l10n.period30Days,
      _Period.months3: l10n.period3Months,
      _Period.year: l10n.periodYear,
    };

    final start = balances == null
        ? now
        : now.subtract(Duration(days: balances.length - 1));
    final middle = now.subtract(
      Duration(days: ((balances?.length ?? 1) - 1) ~/ 2),
    );

    return CentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoSlidingSegmentedControl<_Period>(
            groupValue: period,
            backgroundColor: c.hairline,
            thumbColor: c.elevated,
            children: {
              for (final p in _Period.values)
                p: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    labels[p]!,
                    style: CentType.subheadline.copyWith(color: c.ink),
                  ),
                ),
            },
            onValueChanged: (p) {
              if (p == null) return;
              HapticFeedback.selectionClick();
              onPeriod(p);
            },
          ),
          const SizedBox(height: CentSpace.lg),
          CentLineChart(
            values: [for (final b in balances ?? const <int>[]) b.toDouble()],
            semanticLabel: balances == null || balances.isEmpty
                ? labels[period]!
                : l10n.balanceChartLabel(
                    labels[period]!,
                    formatMoney(Money(balances.first, currency)),
                    formatMoney(Money(balances.last, currency)),
                  ),
          ),
          const SizedBox(height: CentSpace.sm),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in [start, middle, now])
                  Text(
                    shortDate(context, d),
                    style: CentType.caption1.copyWith(color: c.mute),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
