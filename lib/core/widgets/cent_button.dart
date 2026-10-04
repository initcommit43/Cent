import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';
import 'pressable.dart';

enum CentButtonStyle { primary, secondary, compact, onDark, destructive }

/// Pill button. Use one [CentButtonStyle.primary] per screen at most.
class CentButton extends StatelessWidget {
  const CentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = CentButtonStyle.primary,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final CentButtonStyle style;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = style == CentButtonStyle.compact;

    final (Color background, Color foreground, Color? border) = switch (style) {
      CentButtonStyle.primary ||
      CentButtonStyle.compact => (c.primary, c.onPrimary, null),
      CentButtonStyle.secondary => (c.canvas, c.primaryText, c.primaryText),
      CentButtonStyle.onDark => (c.onDarkButton, c.onDarkButtonText, null),
      CentButtonStyle.destructive => (c.canvas, c.negative, c.negative),
    };

    final content = Container(
      height: compact ? CentSize.buttonCompact : CentSize.button,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? CentSpace.lg : CentSpace.xl,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CentRadius.pill),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 18 : 20, color: foreground),
            const SizedBox(width: CentSpace.sm),
          ],
          Text(
            label,
            style: (compact ? CentType.buttonSmall : CentType.buttonLarge)
                .copyWith(color: foreground),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Pressable(
        semanticLabel: label,
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        // Compact buttons are 36pt tall but keep a 44pt touch target.
        child: compact
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: content,
              )
            : content,
      ),
    );
  }
}
