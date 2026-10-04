import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/cent_theme.dart';
import 'data/providers.dart';
import 'l10n/app_localizations.dart';

class CentApp extends ConsumerWidget {
  const CentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: CentTheme.light(),
      darkTheme: CentTheme.dark(),
      themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
