import 'package:flutter/material.dart';

import '../../core/widgets/large_title_scaffold.dart';
import '../../l10n/app_localizations.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(title: AppLocalizations.of(context).tabActivity);
  }
}
