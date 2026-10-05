import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/money/currency.dart';
import '../../core/money/money_format.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_style.dart';
import '../activity/activity_providers.dart';

Future<int?> pickCategory(
  BuildContext context, {
  required CategoryKind kind,
  int? selectedId,
  Set<int> exclude = const {},
}) => showCentSheet<int>(
  context,
  builder: (_) =>
      _CategoryPicker(kind: kind, selectedId: selectedId, exclude: exclude),
);

Future<int?> pickAccount(
  BuildContext context, {
  int? selectedId,
  int? excludeId,
}) => showCentSheet<int>(
  context,
  builder: (_) => _AccountPicker(selectedId: selectedId, excludeId: excludeId),
);

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) {
  var value = initial;
  final l10n = AppLocalizations.of(context);
  return showCentSheet<DateTime>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: l10n.chooseDate,
          cancelLabel: l10n.cancel,
          actionLabel: l10n.done,
          onAction: () => Navigator.of(sheetContext).pop(value),
        ),
        SizedBox(
          height: 216,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(sheetContext).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: CentType.title3.copyWith(
                  color: sheetContext.colors.ink,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              initialDateTime: initial,
              maximumDate: DateTime.now().add(const Duration(days: 365)),
              use24hFormat: true,
              onDateTimeChanged: (v) => value = v,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.paddingOf(sheetContext).bottom + 12),
      ],
    ),
  );
}

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.kind,
    this.selectedId,
    this.exclude = const {},
  });

  final CategoryKind kind;
  final int? selectedId;
  final Set<int> exclude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((cat) => cat.kind == kind && !exclude.contains(cat.id))
        .toList();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(title: l10n.category, cancelLabel: l10n.cancel),
          Padding(
            padding: EdgeInsets.fromLTRB(margin, 12, margin, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cell = constraints.maxWidth / 5;
                return Wrap(
                  runSpacing: 18,
                  children: [
                    for (final cat in categories)
                      SizedBox(
                        width: cell,
                        child: Semantics(
                          button: true,
                          selected: cat.id == selectedId,
                          label: cat.name,
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop(cat.id);
                            },
                            child: Column(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cat.id == selectedId
                                          ? c.primary
                                          : Colors.transparent,
                                      width: 2,
                                      strokeAlign:
                                          BorderSide.strokeAlignOutside,
                                    ),
                                  ),
                                  child: CategoryTile(
                                    icon: CentIcons.named(cat.icon),
                                    tint: CentTint.parse(cat.tint),
                                    size: 52,
                                  ),
                                ),
                                const SizedBox(height: CentSpace.sm),
                                Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: CentType.caption1.copyWith(
                                    color: cat.id == selectedId
                                        ? c.ink
                                        : c.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPicker extends ConsumerWidget {
  const _AccountPicker({this.selectedId, this.excludeId});

  final int? selectedId;
  final int? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final accounts = (ref.watch(accountsProvider).value ?? const [])
        .where((a) => a.account.id != excludeId)
        .toList();

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(title: l10n.chooseAccount, cancelLabel: l10n.cancel),
          const SizedBox(height: CentSpace.sm),
          for (var i = 0; i < accounts.length; i++)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(accounts[i].account.id);
              },
              highlightColor: c.hairline.withValues(alpha: 0.6),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CentSpace.lg,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CategoryTile(
                          icon: accountIcon(accounts[i].account.type),
                          tint: accountTint(accounts[i].account.type),
                        ),
                        const SizedBox(width: CentSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accounts[i].account.name,
                                style: CentType.body.copyWith(color: c.ink),
                              ),
                              Text(
                                formatMoney(accounts[i].balance),
                                style: CentType.subheadlineTabular.copyWith(
                                  color: c.mute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (accounts[i].account.id == selectedId)
                          Icon(CentIcons.check, size: 20, color: c.primaryText),
                      ],
                    ),
                  ),
                  if (i < accounts.length - 1) const InsetDivider(),
                ],
              ),
            ),
          const SizedBox(height: CentSpace.lg),
        ],
      ),
    );
  }
}

Future<Currency?> pickCurrency(BuildContext context, {Currency? selected}) =>
    showCentSheet<Currency>(
      context,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _CurrencyPicker(selected: selected),
      ),
    );

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({this.selected});

  final Currency? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        SheetHeader(title: l10n.currency, cancelLabel: l10n.cancel),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              top: CentSpace.sm,
              bottom: MediaQuery.paddingOf(context).bottom + CentSpace.lg,
            ),
            itemCount: Currency.supported.length,
            itemBuilder: (context, i) {
              final currency = Currency.supported[i];
              return CurrencyRow(
                currency: currency,
                selected: currency == selected,
                showDivider: i < Currency.supported.length - 1,
                onTap: () => Navigator.of(context).pop(currency),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One currency in a pick-one list: symbol tile, name, code, checkmark.
class CurrencyRow extends StatelessWidget {
  const CurrencyRow({
    super.key,
    required this.currency,
    required this.selected,
    required this.onTap,
    this.showDivider = true,
  });

  final Currency currency;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CentSpace.lg,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.tintCopper : c.tintNeutral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currency.symbol,
                    style: CentType.headline.copyWith(
                      color: selected ? c.primaryText : c.ink,
                    ),
                  ),
                ),
                const SizedBox(width: CentSpace.md),
                Expanded(
                  child: Text(
                    currency.name,
                    style: CentType.body.copyWith(color: c.ink),
                  ),
                ),
                Text(
                  currency.code,
                  style: CentType.subheadline.copyWith(color: c.mute),
                ),
                SizedBox(
                  width: 32,
                  child: selected
                      ? Icon(CentIcons.check, size: 20, color: c.primaryText)
                      : null,
                ),
              ],
            ),
          ),
          if (showDivider) const InsetDivider(),
        ],
      ),
    );
  }
}
