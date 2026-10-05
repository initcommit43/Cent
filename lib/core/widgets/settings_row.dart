import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';
import 'list_parts.dart';

/// A grouped-list row: optional tinted icon, label, optional value or
/// subtitle, and a chevron or a switch.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.tint = CentTint.copper,
    this.value,
    this.subtitle,
    this.onTap,
    this.switchValue,
    this.onSwitch,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
    this.showDivider = true,
  });

  final String label;
  final IconData? icon;
  final CentTint tint;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Shows a switch instead of a chevron when set.
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  /// Replaces the chevron, for checkmarks in pick-one lists.
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelColor = destructive ? c.negative : c.ink;

    return InkWell(
      onTap: switchValue == null ? onTap : () => onSwitch?.call(!switchValue!),
      highlightColor: c.hairline.withValues(alpha: 0.6),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                CentSpace.lg,
                subtitle == null ? 6 : 10,
                12,
                subtitle == null ? 6 : 10,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: destructive ? c.tintBlush : tint.background(c),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: destructive ? c.negative : tint.foreground(c),
                      ),
                    ),
                    const SizedBox(width: CentSpace.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: CentType.body.copyWith(color: labelColor),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: CentType.subheadline.copyWith(color: c.mute),
                          ),
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: CentSpace.sm),
                    Text(value!, style: CentType.body.copyWith(color: c.mute)),
                  ],
                  if (trailing != null)
                    trailing!
                  else if (switchValue != null)
                    CupertinoSwitch(
                      value: switchValue!,
                      activeTrackColor: c.primary,
                      onChanged: onSwitch,
                    )
                  else if (showChevron && onTap != null)
                    Icon(CentIcons.forward, size: 18, color: c.mute),
                ],
              ),
            ),
          ),
          if (showDivider)
            InsetDivider(indent: icon == null ? CentSpace.lg : 58),
        ],
      ),
    );
  }
}

/// Section header, grouped card and optional footer, as in iOS Settings.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CentSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionHeader(title: title!),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.canvas,
              borderRadius: BorderRadius.circular(CentRadius.xl),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CentRadius.xl),
              child: Column(children: children),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CentSpace.lg,
                8,
                CentSpace.lg,
                0,
              ),
              child: Text(
                footer!,
                style: CentType.footnote.copyWith(color: context.colors.mute),
              ),
            ),
        ],
      ),
    );
  }
}
