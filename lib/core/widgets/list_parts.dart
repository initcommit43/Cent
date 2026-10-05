import 'package:flutter/material.dart';

import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

/// All-caps footnote above a grouped list, with an optional trailing value
/// or action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trailingStyle = CentType.footnote.copyWith(
      color: onTrailingTap == null ? c.mute : c.primaryText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CentSpace.lg,
        0,
        CentSpace.lg,
        CentSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: CentType.footnote.copyWith(
                color: c.mute,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailingTap,
              child: Padding(
                // Grows the tap area without shifting the text.
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(trailing!, style: trailingStyle),
              ),
            ),
        ],
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.icon,
    required this.tint,
    this.size = CentSize.categoryTile,
  });

  final IconData icon;
  final CentTint tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.background(c),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(icon, size: size / 2, color: tint.foreground(c)),
    );
  }
}

/// Hairline separator inset from the leading edge, as in iOS grouped lists.
class InsetDivider extends StatelessWidget {
  const InsetDivider({super.key, this.indent = 68});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent),
    child: Container(height: 1, color: context.colors.hairline),
  );
}

class CentIconButton extends StatelessWidget {
  const CentIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: CentSize.touchTarget,
        child: Icon(icon, size: 22, color: context.colors.primaryText),
      ),
    ),
  );
}

class CentProgressBar extends StatelessWidget {
  const CentProgressBar({super.key, required this.value, required this.color});

  /// 0 to 1; values above 1 render full.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CentRadius.pill),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: context.colors.canvasSoft),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(CentRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
