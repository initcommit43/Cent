import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

class CentChip extends StatelessWidget {
  const CentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // 32pt chip inside a 44pt touch target.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: CentSize.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? c.chipSelected : c.canvas,
              borderRadius: BorderRadius.circular(CentRadius.pill),
              border: selected ? null : Border.all(color: c.hairline),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: CentType.subheadline.copyWith(
                  color: selected ? c.onChipSelected : c.secondary,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
