import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/money/currency.dart';
import '../../core/money/exchange_rate.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/settings_row.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/pickers.dart';

final _ratesProvider = StreamProvider.autoDispose<List<StoredRate>>((
  ref,
) async* {
  final base = await ref.watch(baseCurrencyProvider.future);
  yield* ref.watch(ratesRepositoryProvider).watchFor(base);
});

final _updatedAtProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.ratesUpdatedAt)
      .map((v) => v == null ? null : DateTime.tryParse(v)),
);

class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Exception {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeBase(Currency current) async {
    final l10n = AppLocalizations.of(context);
    final picked = await pickCurrency(context, selected: current);
    if (picked == null || picked == current) return;
    // Switch only once rates for the new base exist, so every total can
    // still be converted.
    await _run(() async {
      await ref.read(ratesServiceProvider).refresh(picked);
      await ref
          .read(settingsRepositoryProvider)
          .write(SettingKeys.baseCurrency, picked.code);
    }, l10n.baseChangeFailed(picked.code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = ref.watch(baseCurrencyProvider).value ?? Currency.eur;
    final rates = [...?ref.watch(_ratesProvider).value]
      ..sort((a, b) => a.quote.compareTo(b.quote));
    final updated = ref.watch(_updatedAtProvider).value;
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return InlineScaffold(
      title: l10n.currency,
      backLabel: l10n.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, 0, margin, 40),
        children: [
          SettingsSection(
            footer: l10n.baseCurrencyFooter,
            children: [
              SettingsRow(
                icon: CentIcons.globe,
                label: l10n.baseCurrency,
                value: '${base.code} · ${base.name}',
                showDivider: false,
                onTap: _busy ? null : () => unawaited(_changeBase(base)),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.exchangeRates,
            footer: updated == null
                ? l10n.ratesNeverUpdated
                : l10n.ratesFooter(
                    '${dayLabel(context, updated, now)}, ${timeLabel(context, updated)}',
                  ),
            children: [
              for (var i = 0; i < rates.length; i++)
                _RateRow(rate: rates[i], showDivider: i < rates.length - 1),
            ],
          ),
          SettingsSection(
            footer: _error,
            children: [
              SettingsRow(
                icon: CentIcons.refresh,
                label: _busy ? l10n.refreshing : l10n.refreshRates,
                showChevron: false,
                showDivider: false,
                onTap: _busy
                    ? null
                    : () => unawaited(
                        _run(
                          () => ref.read(ratesServiceProvider).refresh(base),
                          l10n.ratesFailed,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateRow extends ConsumerWidget {
  const _RateRow({required this.rate, required this.showDivider});

  final StoredRate rate;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final quote = Currency.of(rate.quote);

    return InkWell(
      onTap: () => unawaited(_editRate(context, ref, rate)),
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CentSpace.lg,
              10,
              CentSpace.lg,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.name,
                        style: CentType.body.copyWith(color: c.ink),
                      ),
                      Text(
                        l10n.rateLine(rate.base, rate.rate, rate.quote),
                        style: CentType.subheadlineTabular.copyWith(
                          color: c.mute,
                        ),
                      ),
                    ],
                  ),
                ),
                if (rate.isManual)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.tag,
                      borderRadius: BorderRadius.circular(CentRadius.pill),
                    ),
                    child: Text(
                      l10n.manual,
                      style: CentType.caption2.copyWith(color: c.tagText),
                    ),
                  )
                else
                  Text(l10n.auto, style: CentType.body.copyWith(color: c.mute)),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: CentSpace.lg),
              child: Container(height: 1, color: c.hairline),
            ),
        ],
      ),
    );
  }

  Future<void> _editRate(
    BuildContext context,
    WidgetRef ref,
    StoredRate rate,
  ) => showCentSheet<void>(context, builder: (_) => _RateSheet(rate: rate));
}

class _RateSheet extends ConsumerStatefulWidget {
  const _RateSheet({required this.rate});

  final StoredRate rate;

  @override
  ConsumerState<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends ConsumerState<_RateSheet> {
  late final _value = TextEditingController(text: widget.rate.rate);

  bool get _valid =>
      RegExp(r'^\d+(\.\d+)?$').hasMatch(_value.text.trim()) &&
      double.parse(_value.text.trim()) > 0;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(ratesRepositoryProvider)
        .setManual(
          ExchangeRate(
            base: Currency.of(widget.rate.base),
            quote: Currency.of(widget.rate.quote),
            rate: _value.text.trim(),
          ),
        );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _useAutomatic() async {
    final base = Currency.of(widget.rate.base);
    await ref
        .read(ratesRepositoryProvider)
        .clearManual(base, Currency.of(widget.rate.quote));
    if (mounted) Navigator.of(context).pop();
    // Fetch the official rate now; offline, the last value stays.
    await ref.read(ratesServiceProvider).refreshIfStale(base);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: l10n.editRate,
              cancelLabel: l10n.cancel,
              actionLabel: l10n.save,
              onAction: _valid ? () => unawaited(_save()) : null,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoTextField(
                    controller: _value,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: CentType.title1.copyWith(
                      color: c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '1 ${widget.rate.base} =',
                        style: CentType.body.copyWith(color: c.mute),
                      ),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        widget.rate.quote,
                        style: CentType.body.copyWith(color: c.mute),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.canvasSoft,
                      borderRadius: BorderRadius.circular(CentRadius.lg),
                    ),
                  ),
                  const SizedBox(height: CentSpace.sm),
                  Text(
                    l10n.rateHint(widget.rate.quote, widget.rate.base),
                    style: CentType.footnote.copyWith(color: c.mute),
                  ),
                  if (widget.rate.isManual) ...[
                    const SizedBox(height: CentSpace.lg),
                    CentButton(
                      label: l10n.useAutomaticRate,
                      style: CentButtonStyle.secondary,
                      expand: true,
                      onPressed: () => unawaited(_useAutomatic()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
