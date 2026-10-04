import 'package:flutter/material.dart';

import '../../theme/cent_theme.dart';
import '../../theme/cent_typography.dart';

/// One horizontal bar split into proportional segments, with 2pt gaps.
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.parts, this.height = 12});

  /// (share 0–1, color) pairs.
  final List<(double, Color)> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = parts.where((p) => p.$1 > 0).toList();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Row(
            // Segments have no content of their own, so they must stretch
            // to the bar's height.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  // Flex needs integers; thousandths keep the proportions.
                  flex: (visible[i].$1 * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: visible[i].$2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical bars with a label under each; groups hold one or two bars.
class GroupedBars extends StatelessWidget {
  const GroupedBars({
    super.key,
    required this.groups,
    required this.semanticLabel,
    this.height = 150,
    this.valueLabels,
  });

  /// Per group: its label and its bars as (value, color).
  final List<(String, List<(double, Color)>)> groups;
  final String semanticLabel;
  final double height;

  /// Optional text above each group, such as the amount.
  final List<String>? valueLabels;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = groups
        .expand((g) => g.$2.map((b) => b.$1))
        .fold<double>(0, (m, v) => v > m ? v : m);
    final barWidth = groups.isNotEmpty && groups.first.$2.length > 1
        ? 14.0
        : 34.0;

    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < groups.length; i++)
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (valueLabels != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        valueLabels![i],
                        style: CentType.caption1.copyWith(color: c.mute),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (value, color) in groups[i].$2) ...[
                        Container(
                          width: barWidth,
                          height: max == 0
                              ? 2
                              : (value / max * (height - 44)).clamp(2, height),
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    groups[i].$1,
                    style: CentType.caption1.copyWith(
                      color: i == groups.length - 1 ? c.ink : c.mute,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
