import 'package:flutter/material.dart';

import '../../core/widgets/large_title_scaffold.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(title: AppLocalizations.of(context).tabHome);
  }
}
