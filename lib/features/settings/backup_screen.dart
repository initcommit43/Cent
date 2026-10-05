import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/dates.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/settings_row.dart';
import '../../data/backup_service.dart';
import '../../data/demo_seeder.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';

final _lastBackupProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.lastBackupAt)
      .map((v) => v == null ? null : DateTime.tryParse(v)),
);

final demoLoadedProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.demoData)
      .map((v) => v == 'true'),
);

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lastBackup = ref.watch(_lastBackupProvider).value;
    final demo = ref.watch(demoLoadedProvider).value ?? false;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return InlineScaffold(
      title: l10n.backupAndExport,
      backLabel: l10n.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, 0, margin, 40),
        children: [
          SettingsSection(
            title: l10n.backupSection,
            footer: lastBackup == null
                ? l10n.noBackupYet
                : l10n.lastBackup(fullDate(context, lastBackup)),
            children: [
              SettingsRow(
                icon: CentIcons.upload,
                label: l10n.exportBackup,
                subtitle: l10n.exportBackupBody,
                onTap: () => unawaited(_exportBackup(context, ref)),
              ),
              SettingsRow(
                icon: CentIcons.download,
                label: l10n.importBackup,
                subtitle: l10n.importBackupBody,
                showDivider: false,
                onTap: () => unawaited(_importBackup(context, ref)),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.spreadsheetSection,
            children: [
              SettingsRow(
                icon: CentIcons.file,
                tint: CentTint.brass,
                label: l10n.exportCsv,
                subtitle: l10n.exportCsvBody,
                showDivider: false,
                onTap: () => unawaited(_exportCsv(context, ref)),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.demoData,
            children: [
              SettingsRow(
                icon: CentIcons.refresh,
                tint: CentTint.neutral,
                label: demo ? l10n.clearDemoData : l10n.loadDemoData,
                subtitle: demo ? l10n.clearDemoDataBody : l10n.loadDemoDataBody,
                showChevron: false,
                showDivider: false,
                onTap: () => unawaited(
                  demo
                      ? _eraseAll(context, ref, demo: true)
                      : _loadDemo(context, ref),
                ),
              ),
            ],
          ),
          SettingsSection(
            footer: l10n.eraseAllFooter,
            children: [
              SettingsRow(
                icon: CentIcons.delete,
                label: l10n.eraseAll,
                destructive: true,
                showChevron: false,
                showDivider: false,
                onTap: () => unawaited(_eraseAll(context, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    String name,
    String content,
    String mimeType,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider)();
    final json = await ref.read(backupServiceProvider).exportJson(now);
    if (!context.mounted) return;
    await _share(
      context,
      'cent-${DateFormat('yyyy-MM-dd').format(now)}.cent',
      json,
      'application/json',
    );
    await ref
        .read(settingsRepositoryProvider)
        .write(SettingKeys.lastBackupAt, now.toIso8601String());
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider)();
    final csv = await ref.read(backupServiceProvider).exportCsv();
    if (!context.mounted) return;
    await _share(
      context,
      'cent-transactions-${DateFormat('yyyy-MM-dd').format(now)}.csv',
      csv,
      'text/csv',
    );
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(backupServiceProvider);
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || !context.mounted) return;

    final String json;
    final BackupInfo info;
    try {
      json = utf8.decode(await picked.first.readAsBytes());
      info = service.inspect(json);
    } on Exception {
      if (context.mounted) await showNotice(context, l10n.importFailed);
      return;
    }
    if (!context.mounted) return;

    final confirmed = await confirmDestructive(
      context,
      message: l10n.importConfirm(
        fullDate(context, info.exportedAt),
        info.transactions,
      ),
      action: l10n.importReplace,
    );
    if (!confirmed) return;
    try {
      await service.importJson(json);
    } on Exception {
      if (context.mounted) await showNotice(context, l10n.importFailed);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    if (context.mounted) await showNotice(context, l10n.importDone);
  }

  Future<void> _loadDemo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      message: l10n.loadDemoConfirm,
      action: l10n.loadDemoData,
    );
    if (!confirmed) return;
    await DemoSeeder(
      ref.read(databaseProvider),
      now: ref.read(clockProvider)(),
    ).seed();
    unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _eraseAll(
    BuildContext context,
    WidgetRef ref, {
    bool demo = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      message: demo ? l10n.clearDemoConfirm : l10n.eraseAllConfirm,
      action: demo ? l10n.clearDemoData : l10n.eraseAll,
    );
    if (!confirmed) return;
    await ref.read(backupServiceProvider).eraseAll();
  }
}
