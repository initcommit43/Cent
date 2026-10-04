import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/settings_row.dart';
import '../../l10n/app_localizations.dart';

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final info = ref.watch(packageInfoProvider).value;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return InlineScaffold(
      title: l10n.aboutCent,
      backLabel: l10n.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.lg, margin, 40),
        children: [
          const Center(child: AppIcon(size: 104)),
          const SizedBox(height: CentSpace.md),
          Text(
            l10n.appTitle,
            textAlign: TextAlign.center,
            style: CentType.title2.copyWith(color: c.ink),
          ),
          if (info != null)
            Text(
              l10n.version('${info.version} (${info.buildNumber})'),
              textAlign: TextAlign.center,
              style: CentType.subheadline.copyWith(color: c.mute),
            ),
          SettingsSection(
            children: [
              SettingsRow(
                icon: CentIcons.named('shield'),
                tint: CentTint.patina,
                label: l10n.aboutPrivacy,
                subtitle: l10n.aboutPrivacyBody,
                showChevron: false,
              ),
              SettingsRow(
                icon: CentIcons.globe,
                label: l10n.aboutRates,
                subtitle: l10n.aboutRatesBody,
                showChevron: false,
              ),
              SettingsRow(
                icon: CentIcons.info,
                tint: CentTint.neutral,
                label: l10n.aboutLicences,
                subtitle: l10n.aboutLicencesBody,
                showDivider: false,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: info?.version,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
