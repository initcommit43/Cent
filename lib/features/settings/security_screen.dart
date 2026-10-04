import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/settings_row.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../lock/app_lock.dart';

const _lockDelays = [
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(hours: 1),
];

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(appLockProvider).value ?? false;
    final after = ref.watch(lockAfterProvider).value ?? Duration.zero;
    final blur = ref.watch(blurInSwitcherProvider).value ?? true;
    final faceId = ref.watch(usesFaceIdProvider).value ?? false;
    final settings = ref.read(settingsRepositoryProvider);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final method = faceId ? l10n.biometricsFaceId : l10n.biometricsGeneric;

    String delayLabel(Duration d) => switch (d.inMinutes) {
      0 => l10n.lockImmediately,
      60 => l10n.lockAfterHour,
      final m => l10n.lockAfterMinutes(m),
    };

    return InlineScaffold(
      title: l10n.securityOptions,
      backLabel: l10n.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, 0, margin, 40),
        children: [
          SettingsSection(
            footer: l10n.appLockFooter(method),
            children: [
              SettingsRow(
                icon: CentIcons.faceId,
                tint: CentTint.patina,
                label: faceId ? l10n.faceIdLock : l10n.appLock,
                switchValue: enabled,
                showDivider: false,
                onSwitch: (on) => unawaited(setAppLock(context, ref, on: on)),
              ),
            ],
          ),
          if (enabled)
            SettingsSection(
              title: l10n.requireAfter(
                faceId ? l10n.biometricsFaceId : l10n.appLock,
              ),
              children: [
                for (var i = 0; i < _lockDelays.length; i++)
                  SettingsRow(
                    label: delayLabel(_lockDelays[i]),
                    showChevron: false,
                    showDivider: i < _lockDelays.length - 1,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      unawaited(
                        settings.write(
                          SettingKeys.appLockAfterSeconds,
                          '${_lockDelays[i].inSeconds}',
                        ),
                      );
                    },
                    trailing: _lockDelays[i] == after
                        ? Icon(CentIcons.check, size: 20, color: c.primary)
                        : null,
                  ),
              ],
            ),
          SettingsSection(
            footer: l10n.blurInSwitcherFooter,
            children: [
              SettingsRow(
                icon: CentIcons.eyeOff,
                tint: CentTint.patina,
                label: l10n.blurInSwitcher,
                switchValue: blur,
                showDivider: false,
                onSwitch: (on) => unawaited(
                  settings.writeBool(SettingKeys.blurInSwitcher, value: on),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
