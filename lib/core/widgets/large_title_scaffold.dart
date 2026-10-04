import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

/// Top-level screen with an iOS large title that collapses to an inline
/// title on scroll.
///
/// With [band] the title sits on the cream header band and the band extends
/// behind [lead]. Set [leadOverlap] to let a hero card straddle the band's
/// bottom edge instead.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    this.band = false,
    this.lead,
    this.leadOverlap,
    this.slivers = const [],
    this.searchField,
    this.onSearchActiveChanged,
  });

  final String title;
  final List<Widget> actions;
  final bool band;
  final Widget? lead;

  /// How far the band reaches into [lead]; null covers all of it.
  final double? leadOverlap;
  final List<Widget> slivers;

  /// Shown under the large title, iOS style: it slides away as content
  /// scrolls up and returns when pulling down at the top. Tapping it moves
  /// it into the bar with a Cancel button.
  final Widget? searchField;
  final ValueChanged<bool>? onSearchActiveChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final trailing = actions.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: actions);
    final background = band ? c.header : c.material;
    final border = band
        ? null
        : Border(bottom: BorderSide(color: c.hairline, width: 0));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (searchField == null)
            CupertinoSliverNavigationBar(
              largeTitle: Text(title),
              automaticallyImplyLeading: false,
              trailing: trailing,
              backgroundColor: background,
              border: border,
              stretch: true,
            )
          else
            CupertinoSliverNavigationBar.search(
              searchField: searchField!,
              onSearchableBottomTap: onSearchActiveChanged,
              largeTitle: Text(title),
              automaticallyImplyLeading: false,
              trailing: trailing,
              backgroundColor: background,
              border: border,
              stretch: true,
            ),
          if (lead != null)
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  if (band)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: leadOverlap,
                      bottom: leadOverlap == null ? 0 : null,
                      child: ColoredBox(color: c.header),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      margin,
                      8,
                      margin,
                      band && leadOverlap == null ? CentSpace.lg : 0,
                    ),
                    child: lead,
                  ),
                ],
              ),
            ),
          ...slivers,
          // Keeps the last item clear of the translucent tab bar.
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 80,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushed screen with a back button and an inline title.
class InlineScaffold extends StatelessWidget {
  const InlineScaffold({
    super.key,
    required this.body,
    this.title,
    this.backLabel,
    this.trailing,
    this.bottom,
  });

  final Widget body;
  final String? title;
  final String? backLabel;
  final Widget? trailing;

  /// Pinned bottom action area, above the home indicator.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: title == null ? null : Text(title!),
        automaticallyImplyLeading: false,
        leading: _BackButton(label: backLabel),
        trailing: trailing,
        backgroundColor: c.canvasSoft,
        border: null,
      ),
      body: body,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(margin, 8, margin, 12),
              child: bottom!,
            ),
    );
  }
}

/// Lucide chevron plus the previous screen's title, as on iOS.
class _BackButton extends StatelessWidget {
  const _BackButton({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final back = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: label ?? back,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CentSize.touchTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CentIcons.back, size: 24, color: c.primaryText),
              if (label != null)
                Text(
                  label!,
                  style: CentType.body.copyWith(color: c.primaryText),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
