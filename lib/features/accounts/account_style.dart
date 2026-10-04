import 'package:flutter/widgets.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/cent_icons.dart';
import '../../l10n/app_localizations.dart';

IconData accountIcon(AccountType type) => switch (type) {
  AccountType.checking => CentIcons.checking,
  AccountType.savings => CentIcons.savings,
  AccountType.cash => CentIcons.cash,
  AccountType.card => CentIcons.card,
};

CentTint accountTint(AccountType type) => switch (type) {
  AccountType.checking => CentTint.copper,
  AccountType.savings => CentTint.patina,
  AccountType.cash => CentTint.brass,
  AccountType.card => CentTint.blush,
};

String accountTypeLabel(AppLocalizations l10n, AccountType type) =>
    switch (type) {
      AccountType.checking => l10n.typeChecking,
      AccountType.savings => l10n.typeSavings,
      AccountType.cash => l10n.typeCash,
      AccountType.card => l10n.typeCard,
    };
