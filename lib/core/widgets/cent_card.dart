import 'package:flutter/material.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';

/// Inset card on the screen background. Shadow only in light mode; dark
/// mode separates surfaces by lightness instead.
class CentCard extends StatelessWidget {
  const CentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CentSpace.lg),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? c.canvas,
        borderRadius: BorderRadius.circular(CentRadius.xl),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0x0F10302B),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Grouped list container: rows sit flush inside a rounded card.
class CentGroup extends StatelessWidget {
  const CentGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CentCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}
