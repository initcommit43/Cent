import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/amount_field.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_chip.dart';
import '../../core/widgets/cent_text_field.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/settings_row.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_style.dart';
import '../common/pickers.dart';
import '../lock/app_lock.dart';

enum _Step { welcome, currency, account, start, lock }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.welcome;
  bool _forward = true;
  bool _saving = false;

  Currency _base = Currency.eur;
  final _search = TextEditingController();
  final _name = TextEditingController();
  AccountType _type = AccountType.checking;
  Currency? _accountCurrency;
  final _balance = TextEditingController();
  bool _demo = true;

  Currency get _currencyOfAccount => _accountCurrency ?? _base;

  int? get _balanceMinor =>
      parseAmountMinor(_balance.text, _currencyOfAccount, allowNegative: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      _name.text = AppLocalizations.of(context).defaultAccountName;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _go(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step.index > _step.index;
      _step = step;
    });
  }

  bool get _canContinue => switch (_step) {
    _Step.account => _name.text.trim().isNotEmpty && _balanceMinor != null,
    _ => true,
  };

  Future<void> _finish({required bool appLock}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final service = ref.read(onboardingServiceProvider);
    if (_demo) {
      await service.startWithDemo(
        now: ref.read(clockProvider)(),
        appLock: appLock,
      );
    } else {
      await service.startFresh(
        base: _base,
        accountName: _name.text.trim(),
        accountType: _type,
        openingBalance: Money(_balanceMinor ?? 0, _currencyOfAccount),
        appLock: appLock,
      );
    }
    unawaited(HapticFeedback.mediumImpact());
    // The router leaves onboarding on its own once it is marked done.
    final base = _demo ? Currency.eur : _base;
    unawaited(ref.read(ratesServiceProvider).refreshIfStale(base));
  }

  Future<void> _turnOnLock() async {
    final l10n = AppLocalizations.of(context);
    final supported = await ref
        .read(localAuthProvider)
        .isDeviceSupported()
        .catchError((Object _) => false);
    if (!mounted) return;
    if (!supported) {
      await showNotice(context, l10n.lockUnavailable);
      return;
    }
    if (await authenticate(ref, l10n.unlockReason)) {
      await _finish(appLock: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final page = switch (_step) {
      _Step.welcome => _Welcome(onStart: () => _go(_Step.currency)),
      _Step.currency => _currencyStep(context),
      _Step.account => _accountStep(context),
      _Step.start => _startStep(context),
      _Step.lock => _lockStep(context),
    };

    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Step.values[_step.index - 1]);
      },
      child: Scaffold(
        backgroundColor: c.canvasSoft,
        resizeToAvoidBottomInset: false,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_step);
            final dx = (incoming == _forward) ? 0.12 : -0.12;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(_step), child: page),
        ),
      ),
    );
  }

  Widget _currencyStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _search.text.trim().toLowerCase();
    final matches = Currency.supported
        .where(
          (cur) =>
              query.isEmpty ||
              cur.name.toLowerCase().contains(query) ||
              cur.code.toLowerCase().contains(query),
        )
        .toList();

    return _StepScaffold(
      step: 1,
      title: l10n.chooseCurrencyTitle,
      body: l10n.chooseCurrencyBody,
      onBack: () => _go(_Step.welcome),
      onContinue: () => _go(_Step.account),
      children: [
        CentSearchField(
          placeholder: l10n.searchCurrencies,
          controller: _search,
          autofocus: false,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CentSpace.md),
        _Group(
          children: [
            for (var i = 0; i < matches.length; i++)
              CurrencyRow(
                currency: matches[i],
                selected: matches[i] == _base,
                showDivider: i < matches.length - 1,
                onTap: () => setState(() => _base = matches[i]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _accountStep(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: CentType.footnote.copyWith(color: c.secondary)),
    );

    return _StepScaffold(
      step: 2,
      title: l10n.firstAccountTitle,
      body: l10n.firstAccountBody,
      onBack: () => _go(_Step.currency),
      onContinue: _canContinue ? () => _go(_Step.start) : null,
      children: [
        CentTextField(
          label: l10n.fieldName,
          controller: _name,
          capitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        label(l10n.accountType),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in AccountType.values)
              CentChip(
                label: accountTypeLabel(l10n, type),
                selected: type == _type,
                onTap: () => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: CentSpace.lg),
        _Group(
          children: [
            SettingsRow(
              icon: CentIcons.globe,
              label: l10n.currency,
              value: _currencyOfAccount.code,
              showDivider: false,
              onTap: () async {
                final picked = await pickCurrency(
                  context,
                  selected: _currencyOfAccount,
                );
                if (picked != null) setState(() => _accountCurrency = picked);
              },
            ),
          ],
        ),
        label(l10n.startingBalance),
        AmountField(
          controller: _balance,
          currency: _currencyOfAccount,
          allowNegative: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CentSpace.sm),
        Text(
          l10n.startingBalanceHint,
          style: CentType.footnote.copyWith(color: c.mute),
        ),
      ],
    );
  }

  Widget _startStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    return _StepScaffold(
      step: 3,
      title: l10n.howToStartTitle,
      body: l10n.howToStartBody,
      onBack: () => _go(_Step.account),
      onContinue: () => _go(_Step.lock),
      children: [
        _Option(
          icon: CentIcons.chart,
          title: l10n.demoOptionTitle,
          body: l10n.demoOptionBody,
          selected: _demo,
          onTap: () => setState(() => _demo = true),
        ),
        const SizedBox(height: CentSpace.md),
        _Option(
          icon: CentIcons.add,
          title: l10n.freshOptionTitle,
          body: l10n.freshOptionBody(name),
          selected: !_demo,
          onTap: () => setState(() => _demo = false),
        ),
      ],
    );
  }

  Widget _lockStep(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final faceId = ref.watch(usesFaceIdProvider).value ?? false;
    final method = faceId ? l10n.biometricsFaceId : l10n.biometricsGeneric;

    return _StepScaffold(
      step: 4,
      onBack: () => _go(_Step.start),
      actions: [
        CentButton(
          label: l10n.turnOnLock(
            faceId ? l10n.biometricsFaceId : l10n.appLock.toLowerCase(),
          ),
          expand: true,
          onPressed: _saving ? null : () => unawaited(_turnOnLock()),
        ),
        const SizedBox(height: CentSpace.sm),
        CupertinoButton(
          onPressed: _saving ? null : () => unawaited(_finish(appLock: false)),
          child: Text(
            l10n.notNow,
            style: CentType.body.copyWith(color: c.primaryText),
          ),
        ),
      ],
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.tintCopper,
              borderRadius: BorderRadius.circular(CentRadius.xl),
            ),
            child: Icon(CentIcons.faceId, size: 40, color: c.primaryText),
          ),
        ),
        const SizedBox(height: CentSpace.xl),
        Text(
          l10n.lockTitle,
          textAlign: TextAlign.center,
          style: CentType.title1.copyWith(color: c.ink),
        ),
        const SizedBox(height: CentSpace.sm),
        Text(
          l10n.lockBody(method),
          textAlign: TextAlign.center,
          style: CentType.callout.copyWith(color: c.secondary),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: ColoredBox(
            color: c.header,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      '¢',
                      style: CentType.displayHero.copyWith(
                        fontSize: 156,
                        fontWeight: FontWeight.w400,
                        height: 1,
                        color: c.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: CentSpace.lg),
                  Text(
                    l10n.appTitle,
                    style: CentType.title2.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 9,
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(margin, 0, margin, CentSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: CentSpace.xxl),
                Text(
                  l10n.welcomeTitle,
                  style: CentType.title1.copyWith(color: c.ink),
                ),
                const SizedBox(height: CentSpace.sm),
                Text(
                  l10n.welcomeBody,
                  style: CentType.callout.copyWith(color: c.secondary),
                ),
                const Spacer(),
                CentButton(
                  label: l10n.getStarted,
                  expand: true,
                  onPressed: onStart,
                ),
                const SizedBox(height: CentSpace.md),
                Center(
                  child: Text(
                    l10n.welcomeFootnote,
                    style: CentType.footnote.copyWith(color: c.mute),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Back link, four-part progress, title and copy, scrolling content and
/// the bottom action, shared by every step after the welcome.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.step,
    required this.onBack,
    required this.children,
    this.title,
    this.body,
    this.onContinue,
    this.actions,
  });

  final int step;
  final String? title;
  final String? body;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  /// Replaces the Continue button.
  final List<Widget>? actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: CentSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: l10n.back,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(margin - 4, 12, 16, 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CentIcons.back, size: 22, color: c.primaryText),
                      Text(
                        l10n.back,
                        style: CentType.body.copyWith(color: c.primaryText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: Semantics(
              label: l10n.stepOf(step, 4),
              child: Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step ? c.primary : c.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, CentSpace.xl, margin, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (title != null)
                  Text(title!, style: CentType.title1.copyWith(color: c.ink)),
                if (body != null) ...[
                  const SizedBox(height: CentSpace.sm),
                  Text(
                    body!,
                    style: CentType.callout.copyWith(color: c.secondary),
                  ),
                ],
                if (title != null) const SizedBox(height: CentSpace.lg),
                ...children,
              ],
            ),
          ),
          // Rides above the keyboard so Continue is always reachable.
          Padding(
            padding: EdgeInsets.fromLTRB(
              margin,
              CentSpace.sm,
              margin,
              keyboard > 0 ? keyboard + CentSpace.sm : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  actions ??
                  [
                    CentButton(
                      label: l10n.continueLabel,
                      expand: true,
                      onPressed: onContinue,
                    ),
                  ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(CentRadius.xl),
    child: ColoredBox(
      color: context.colors.canvas,
      child: Column(children: children),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(CentSpace.lg),
          decoration: BoxDecoration(
            color: c.canvas,
            borderRadius: BorderRadius.circular(CentRadius.xl),
            border: Border.all(
              color: selected ? c.primary : c.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? c.tintCopper : c.tintNeutral,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? c.primaryText : c.ink,
                ),
              ),
              const SizedBox(width: CentSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CentType.headline.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: CentType.subheadline.copyWith(color: c.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CentSpace.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.primary : null,
                  border: selected
                      ? null
                      : Border.all(color: c.input, width: 1.5),
                ),
                child: selected
                    ? Icon(CentIcons.check, size: 14, color: c.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
