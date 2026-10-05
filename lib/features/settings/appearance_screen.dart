import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cent_colors.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    void select(ThemeMode m) {
      HapticFeedback.selectionClick();
      unawaited(
        ref
            .read(settingsRepositoryProvider)
            .write(SettingKeys.themeMode, m.name),
      );
    }

    return InlineScaffold(
      title: l10n.appearance,
      backLabel: l10n.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.lg, margin, 40),
        children: [
          Row(
            children: [
              for (final (m, label) in [
                (ThemeMode.light, l10n.themeLight),
                (ThemeMode.dark, l10n.themeDark),
                (ThemeMode.system, l10n.themeSystem),
              ]) ...[
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: m == mode,
                    label: label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => select(m),
                      child: Column(
                        children: [
                          _Preview(mode: m, selected: m == mode),
                          const SizedBox(height: CentSpace.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Radio(selected: m == mode),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: CentType.subheadline.copyWith(
                                  color: c.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (m != ThemeMode.system) const SizedBox(width: CentSpace.md),
              ],
            ],
          ),
          const SizedBox(height: CentSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CentSpace.lg),
            child: Text(
              l10n.appearanceFooter,
              style: CentType.footnote.copyWith(color: c.mute),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny phone screen drawn in the mode's colors; System shows both halves.
class _Preview extends StatelessWidget {
  const _Preview({required this.mode, required this.selected});

  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget screen(CentColors p) => ColoredBox(
      color: p.canvasSoft,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 26,
              decoration: BoxDecoration(
                color: p.hero,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Container(width: 40, height: 6, color: p.ink),
            const SizedBox(height: 6),
            for (var i = 0; i < 2; i++) ...[
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: p.canvas,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
            ],
            const Spacer(),
            Container(width: 30, height: 5, color: p.primary),
          ],
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CentRadius.xl),
          border: Border.all(
            color: selected ? c.primary : c.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: switch (mode) {
          ThemeMode.light => screen(CentColors.light),
          ThemeMode.dark => screen(CentColors.dark),
          ThemeMode.system => Stack(
            fit: StackFit.expand,
            children: [
              screen(CentColors.light),
              ClipRect(clipper: _RightHalf(), child: screen(CentColors.dark)),
            ],
          ),
        },
      ),
    );
  }
}

class _RightHalf extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_RightHalf oldClipper) => false;
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.primary : null,
        border: selected ? null : Border.all(color: c.input, width: 1.5),
      ),
      child: selected
          ? Icon(CentIcons.check, size: 12, color: c.onPrimary)
          : null,
    );
  }
}
