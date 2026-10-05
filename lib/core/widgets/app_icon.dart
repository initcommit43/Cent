import 'package:flutter/material.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_typography.dart';

/// The cent sign on copper, the app's mark. Proportions follow the Figma
/// App Icon component: iOS corner ratio, glyph at about 53% height.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(size * 0.225),
        ),
        child: Text(
          '¢',
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: CentType.largeTitle.copyWith(
            color: c.onPrimary,
            fontSize: size * 0.64,
            fontWeight: FontWeight.w500,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
