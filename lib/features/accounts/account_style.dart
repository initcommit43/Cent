import 'package:flutter/widgets.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/cent_icons.dart';

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
