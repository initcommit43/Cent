import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/currency.dart';
import '../../core/router/routes.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/settings_row.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../activity/activity_providers.dart';
import '../lock/app_lock.dart';
import 'about_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final base = ref.watch(baseCurrencyProvider).value ?? Currency.eur;
    final categories = ref.watch(categoriesProvider).value?.length;
    final accounts = ref.watch(accountsProvider).value?.length;
    final theme = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final lock = ref.watch(appLockProvider).value ?? false;
    final faceId = ref.watch(usesFaceIdProvider).value ?? false;
    final demo = ref.watch(demoLoadedProvider).value ?? false;
    final version = ref.watch(packageInfoProvider).value?.version;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    void open(String route) => unawaited(context.push(route));

    return InlineScaffold(
      title: l10n.settings,
      backLabel: l10n.tabHome,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, 0, margin, 40),
        children: [
          SettingsSection(
            title: l10n.settingsGeneral,
            children: [
              SettingsRow(
                icon: CentIcons.globe,
                label: l10n.baseCurrency,
                value: base.code,
                onTap: () => open(Routes.settingsCurrency),
              ),
              SettingsRow(
                icon: CentIcons.tag,
                label: l10n.categories,
                value: categories?.toString(),
                onTap: () => open(Routes.settingsCategories),
              ),
              SettingsRow(
                icon: CentIcons.bank,
                label: l10n.accounts,
                value: accounts?.toString(),
                showDivider: false,
                onTap: () => open(Routes.accounts),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.settingsPreferences,
            children: [
              SettingsRow(
                icon: CentIcons.palette,
                tint: CentTint.brass,
                label: l10n.appearance,
                value: switch (theme) {
                  ThemeMode.light => l10n.themeLight,
                  ThemeMode.dark => l10n.themeDark,
                  ThemeMode.system => l10n.themeSystem,
                },
                showDivider: false,
                onTap: () => open(Routes.settingsAppearance),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.settingsPrivacy,
            footer: l10n.privacyFooter,
            children: [
              SettingsRow(
                icon: CentIcons.faceId,
                tint: CentTint.patina,
                label: faceId ? l10n.faceIdLock : l10n.appLock,
                switchValue: lock,
                onSwitch: (on) => unawaited(setAppLock(context, ref, on: on)),
              ),
              SettingsRow(
                icon: CentIcons.lock,
                tint: CentTint.patina,
                label: l10n.securityOptions,
                showDivider: false,
                onTap: () => open(Routes.settingsSecurity),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.settingsData,
            children: [
              SettingsRow(
                icon: CentIcons.upload,
                tint: CentTint.neutral,
                label: l10n.backupAndExport,
                onTap: () => open(Routes.settingsBackup),
              ),
              SettingsRow(
                icon: CentIcons.refresh,
                tint: CentTint.neutral,
                label: l10n.demoData,
                value: demo ? l10n.loaded : l10n.off,
                showDivider: false,
                onTap: () => open(Routes.settingsBackup),
              ),
            ],
          ),
          SettingsSection(
            children: [
              SettingsRow(
                icon: CentIcons.info,
                tint: CentTint.neutral,
                label: l10n.aboutCent,
                value: version,
                showDivider: false,
                onTap: () => open(Routes.settingsAbout),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
