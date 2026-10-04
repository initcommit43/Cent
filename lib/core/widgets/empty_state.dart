import 'package:flutter/material.dart';

import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';
import 'list_parts.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CentSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryTile(icon: icon, tint: CentTint.copper, size: 72),
          const SizedBox(height: CentSpace.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CentType.title2.copyWith(color: c.ink),
          ),
          const SizedBox(height: CentSpace.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: CentType.callout.copyWith(color: c.secondary),
          ),
          if (action != null) ...[
            const SizedBox(height: CentSpace.md),
            action!,
          ],
        ],
      ),
    );
  }
}
