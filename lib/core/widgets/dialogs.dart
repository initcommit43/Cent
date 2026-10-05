import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';

/// An action sheet with one destructive action; resolves to true when the
/// user confirms.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String message,
  required String action,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      message: Text(message),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(true),
          child: Text(action),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(false),
        child: Text(l10n.cancel),
      ),
    ),
  );
  return confirmed ?? false;
}

/// A short alert with a single Done button.
Future<void> showNotice(BuildContext context, String message) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context).done),
          ),
        ],
      ),
    );
