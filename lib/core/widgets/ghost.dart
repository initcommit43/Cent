import 'package:flutter/material.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import 'cent_card.dart';
import 'list_parts.dart';

// Ghosts are outline sketches of real content. The same shapes preview a
// screen while it's empty and stand in for it while it loads.

class GhostBar extends StatelessWidget {
  const GhostBar({
    super.key,
    required this.width,
    this.height = 10,
    this.color,
  });

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color ?? context.colors.hairline,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

class GhostTile extends StatelessWidget {
  const GhostTile({super.key, this.size = CentSize.categoryTile, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color ?? context.colors.tintNeutral,
      borderRadius: BorderRadius.circular(size / 4),
    ),
  );
}

/// A progress track with a tinted fill, sized like [CentProgressBar].
class GhostProgress extends StatelessWidget {
  const GhostProgress({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CentRadius.pill),
      child: Container(
        height: 6,
        color: c.hairline.withValues(alpha: 0.6),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: Container(color: color ?? c.tintPatina),
        ),
      ),
    );
  }
}

/// A transaction row: tile, title and subtitle, trailing amount.
class GhostRow extends StatelessWidget {
  const GhostRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.tileColor,
    this.showDivider = true,
  });

  final double title;
  final double subtitle;
  final double amount;
  final Color? tileColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: CentSize.row,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CentSpace.lg),
          child: Row(
            children: [
              GhostTile(color: tileColor),
              const SizedBox(width: CentSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GhostBar(width: title, height: 11),
                    const SizedBox(height: CentSpace.sm),
                    GhostBar(width: subtitle, height: 8),
                  ],
                ),
              ),
              GhostBar(width: amount, height: 11),
            ],
          ),
        ),
      ),
      if (showDivider) const InsetDivider(),
    ],
  );
}

/// A grouped list of [rows] transaction rows. Widths vary so it reads as
/// content rather than a pattern; tiles pick up the category tints.
class GhostList extends StatelessWidget {
  const GhostList({super.key, this.rows = 3});

  final int rows;

  static const _shapes = [
    (112.0, 76.0, 52.0),
    (84.0, 96.0, 60.0),
    (128.0, 64.0, 44.0),
    (96.0, 88.0, 56.0),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tints = [c.tintCopper, c.tintPatina, c.tintBrass, c.tintBlush];
    return CentGroup(
      children: [
        for (var i = 0; i < rows; i++)
          GhostRow(
            title: _shapes[i % _shapes.length].$1,
            subtitle: _shapes[i % _shapes.length].$2,
            amount: _shapes[i % _shapes.length].$3,
            tileColor: tints[i % tints.length],
            showDivider: i < rows - 1,
          ),
      ],
    );
  }
}

/// Fades its child out toward the bottom, so a preview reads as a hint
/// of what's coming rather than as real content.
class GhostFade extends StatelessWidget {
  const GhostFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black, Colors.black, Colors.transparent],
      stops: [0, 0.35, 1],
    ).createShader(bounds),
    child: child,
  );
}
