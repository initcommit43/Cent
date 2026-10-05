import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

class CentTabItem {
  const CentTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Translucent iOS-style tab bar that blurs the content scrolling under it.
class CentTabBar extends StatelessWidget {
  const CentTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<CentTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.material,
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: CentSize.tabBar,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _TabButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CentTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.primaryText : c.mute;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(item.label, style: CentType.caption2.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
