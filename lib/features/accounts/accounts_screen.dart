import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
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
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/accounts_repository.dart';
import '../../data/providers.dart';
import '../../data/rates_repository.dart';
import '../../l10n/app_localizations.dart';
import '../add_transaction/add_transaction_sheet.dart';
import 'account_sheet.dart';
import 'account_style.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final converter = ref.watch(converterProvider).value;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    final groups = [
      (l10n.groupEveryday, {AccountType.checking, AccountType.card}),
      (l10n.groupSavings, {AccountType.savings}),
      (l10n.groupCash, {AccountType.cash}),
    ];

    Money? inBase(Iterable<AccountWithBalance> items) {
      if (converter == null) return null;
      var total = Money.zero(converter.base);
      for (final a in items) {
        if (a.account.includeInNetWorth) {
          total += converter.convert(a.balance, converter.base);
        }
      }
      return total;
    }

    final netWorth = inBase(accounts);

    return InlineScaffold(
      title: l10n.accounts,
      backLabel: l10n.tabHome,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => unawaited(showAccountSheet(context)),
        child: Text(l10n.add),
      ),
      bottom: accounts.length < 2
          ? null
          : CentButton(
              label: l10n.transferBetweenAccounts,
              icon: CentIcons.transfer,
              style: CentButtonStyle.secondary,
              expand: true,
              onPressed: () => unawaited(
                showAddTransaction(context, kind: TransactionKind.transfer),
              ),
            ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          Text(
            l10n.netWorth,
            textAlign: TextAlign.center,
            style: CentType.subheadline.copyWith(color: c.mute),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              netWorth == null ? '' : formatMoney(netWorth),
              style: CentType.largeTitle.copyWith(
                color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            l10n.acrossAccounts(accounts.length),
            textAlign: TextAlign.center,
            style: CentType.footnote.copyWith(color: c.mute),
          ),
          for (final (title, types) in groups)
            if (accounts.any((a) => types.contains(a.account.type)))
              Padding(
                padding: const EdgeInsets.only(top: CentSpace.xl),
                child: _AccountGroup(
                  title: title,
                  total: inBase(
                    accounts.where((a) => types.contains(a.account.type)),
                  ),
                  accounts: accounts
                      .where((a) => types.contains(a.account.type))
                      .toList(),
                  converter: converter,
                ),
              ),
        ],
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({
    required this.title,
    required this.total,
    required this.accounts,
    required this.converter,
  });

  final String title;
  final Money? total;
  final List<AccountWithBalance> accounts;
  final CurrencyConverter? converter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          trailing: total == null ? null : formatMoney(total!),
        ),
        CentGroup(
          children: [
            for (var i = 0; i < accounts.length; i++)
              AccountRow(
                item: accounts[i],
                converter: converter,
                showDivider: i < accounts.length - 1,
                onTap: () =>
                    context.push(Routes.account(accounts[i].account.id)),
              ),
          ],
        ),
      ],
    );
  }
}

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.item,
    required this.converter,
    required this.onTap,
    this.showDivider = true,
  });

  final AccountWithBalance item;
  final CurrencyConverter? converter;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final account = item.account;
    final currency = Currency.of(account.currency);
    final foreign = converter != null && currency != converter!.base;

    final subtitle = [
      accountTypeLabel(l10n, account.type),
      account.currency,
      if (foreign)
        l10n.approxAmount(
          formatMoney(converter!.convert(item.balance, converter!.base)),
        ),
    ].join(' · ');

    return InkWell(
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
                    icon: accountIcon(account.type),
                    tint: accountTint(account.type),
                  ),
                  const SizedBox(width: CentSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: CentType.body.copyWith(color: c.ink),
                        ),
                        Text(
                          subtitle,
                          style: CentType.subheadline.copyWith(color: c.mute),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(item.balance),
                    style: CentType.bodyTabular.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
          ),
          if (showDivider) const InsetDivider(),
        ],
      ),
    );
  }
}
