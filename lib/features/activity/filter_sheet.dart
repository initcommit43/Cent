import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_chip.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../data/transactions_repository.dart';
import '../../l10n/app_localizations.dart';
import 'activity_providers.dart';

Future<void> showFilterSheet(BuildContext context) =>
    showCentSheet<void>(context, builder: (_) => const _FilterSheet());

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TransactionKind? _kind;
  late Set<int> _accounts;
  late Set<int> _categories;
  final _min = TextEditingController();
  final _max = TextEditingController();
  late Stream<int> _count;

  @override
  void initState() {
    super.initState();
    final current = ref.read(activityFilterProvider);
    _kind = current.kinds.length == 1 ? current.kinds.first : null;
    _accounts = {...current.accountIds};
    _categories = {...current.categoryIds};
    if (current.minAbsMinor != null) {
      _min.text = '${current.minAbsMinor! ~/ 100}';
    }
    if (current.maxAbsMinor != null) {
      _max.text = '${current.maxAbsMinor! ~/ 100}';
    }
    _refreshCount();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  EntryFilter get _draft => EntryFilter(
    kinds: _kind == null ? const {} : {_kind!},
    accountIds: _accounts,
    categoryIds: _categories,
    minAbsMinor: _toMinor(_min.text),
    maxAbsMinor: _toMinor(_max.text),
  );

  // Amount bounds are whole units of the base currency.
  int? _toMinor(String text) {
    final value = int.tryParse(text.trim());
    return value == null ? null : value * 100;
  }

  void _refreshCount() {
    final month = ref.read(activityMonthProvider);
    _count = ref
        .read(transactionsRepositoryProvider)
        .watchRange(month, nextMonthStart(month), filter: _draft)
        .map((list) => list.length);
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _refreshCount();
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CentType.footnote.copyWith(color: c.secondary)),
          const SizedBox(height: CentSpace.sm),
          child,
        ],
      ),
    );

    Widget chips(Iterable<(int, String)> items, Set<int> selected) => Wrap(
      spacing: CentSpace.sm,
      children: [
        for (final (id, name) in items)
          CentChip(
            label: name,
            selected: selected.contains(id),
            onTap: () => _update(
              () => selected.contains(id)
                  ? selected.remove(id)
                  : selected.add(id),
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: l10n.filters,
            cancelLabel: l10n.cancel,
            actionLabel: l10n.reset,
            onAction: () => _update(() {
              _kind = null;
              _accounts.clear();
              _categories.clear();
              _min.clear();
              _max.clear();
            }),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margin, 0, margin, CentSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section(
                    l10n.filterType,
                    CupertinoSlidingSegmentedControl<int>(
                      groupValue: switch (_kind) {
                        null => 0,
                        TransactionKind.expense => 1,
                        TransactionKind.income => 2,
                        TransactionKind.transfer => 3,
                      },
                      backgroundColor: c.hairline,
                      thumbColor: c.canvas,
                      children: {
                        0: _segment(l10n.all),
                        1: _segment(l10n.expenses),
                        2: _segment(l10n.income),
                        3: _segment(l10n.transfers),
                      },
                      onValueChanged: (value) {
                        HapticFeedback.selectionClick();
                        _update(
                          () => _kind = switch (value) {
                            1 => TransactionKind.expense,
                            2 => TransactionKind.income,
                            3 => TransactionKind.transfer,
                            _ => null,
                          },
                        );
                      },
                    ),
                  ),
                  section(
                    l10n.filterAccounts,
                    chips(
                      accounts.map((a) => (a.account.id, a.account.name)),
                      _accounts,
                    ),
                  ),
                  section(
                    l10n.filterCategories,
                    chips(categories.map((c) => (c.id, c.name)), _categories),
                  ),
                  section(
                    l10n.filterAmount,
                    Row(
                      children: [
                        Expanded(child: _amountField(l10n.filterMin, _min)),
                        const SizedBox(width: CentSpace.md),
                        Expanded(child: _amountField(l10n.filterMax, _max)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(margin, 0, margin, 12),
            child: StreamBuilder<int>(
              stream: _count,
              builder: (context, snapshot) {
                final count = snapshot.data;
                return CentButton(
                  expand: true,
                  label: l10n.showResults(count ?? 0),
                  onPressed: count == 0
                      ? null
                      : () {
                          ref
                              .read(activityFilterProvider.notifier)
                              .apply(_draft);
                          Navigator.of(context).pop();
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      label,
      style: CentType.subheadline.copyWith(color: context.colors.ink),
    ),
  );

  Widget _amountField(String label, TextEditingController controller) {
    final c = context.colors;
    final currency = ref.watch(baseCurrencyProvider).value;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _update(() {}),
      style: CentType.bodyTabular.copyWith(color: c.ink),
      cursorColor: c.primary,
      decoration: InputDecoration(
        // A prefix icon stays visible when the field is empty and unfocused,
        // unlike prefixText.
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Text(
            '$label  ${currency?.symbol ?? ''}',
            style: CentType.subheadline.copyWith(color: c.mute),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: c.canvasSoft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CentRadius.lg),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
