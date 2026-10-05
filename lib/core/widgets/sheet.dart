import 'package:flutter/material.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

/// Opens [builder] as an iOS-style sheet with a grabber and rounded top.
Future<T?> showCentSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool grouped = false,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: grouped ? c.canvasSoft : c.elevated,
    barrierColor: c.backdrop,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CentRadius.xxl)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: builder,
  );
}

/// Grabber plus a Cancel / title / action row.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    required this.cancelLabel,
    this.actionLabel,
    this.onAction,
    this.onCancel,
  });

  final String title;
  final String cancelLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Defaults to closing the sheet.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    TextStyle link(FontWeight weight) =>
        CentType.body.copyWith(color: c.primaryText, fontWeight: weight);

    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: c.input,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(
          height: CentSize.touchTarget,
          child: Row(
            children: [
              TextButton(
                onPressed: onCancel ?? () => Navigator.of(context).pop(),
                child: Text(cancelLabel, style: link(FontWeight.w400)),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: CentType.headline.copyWith(color: c.ink),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!, style: link(FontWeight.w500)),
                )
              else
                // Mirrors the Cancel button so the title stays centered.
                Opacity(
                  opacity: 0,
                  child: TextButton(
                    onPressed: null,
                    child: Text(cancelLabel, style: link(FontWeight.w400)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
