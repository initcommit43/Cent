import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';
import 'cent_button.dart';
import 'ghost.dart';
import 'list_parts.dart';

/// Shown when a screen has nothing to show yet. With a [preview], a faded
/// ghost of the content sits where that content will appear; without one,
/// [icon] marks the state instead, for cases like empty search results
/// where there's nothing to preview.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.preview,
    this.icon,
    required this.title,
    required this.body,
    this.action,
    this.margin,
  }) : assert(preview != null || icon != null);

  final Widget? preview;
  final IconData? icon;
  final String title;
  final String body;
  final Widget? action;

  /// Side inset for the preview. Defaults to the screen margin; pass 0
  /// inside content that's already inset.
  final double? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final margin =
        this.margin ?? CentSpace.margin(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: ExcludeSemantics(child: GhostFade(child: preview!)),
          )
        else
          Center(
            child: CategoryTile(icon: icon!, tint: CentTint.copper, size: 72),
          ),
        SizedBox(height: preview != null ? CentSpace.sm : CentSpace.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CentSpace.xxl),
          child: Column(
            children: [
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
                const SizedBox(height: CentSpace.xl - 4),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Stands in for content that's still loading. Local reads usually finish
/// within a frame, so the ghost only appears after a short delay; showing
/// it at once would flash on every screen change.
class LoadingState extends StatefulWidget {
  const LoadingState({super.key, required this.ghost});

  final Widget ghost;

  static const delay = Duration(milliseconds: 250);

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LoadingState.delay, () {
      setState(() => _visible = true);
      if (!MediaQuery.disableAnimationsOf(context)) {
        unawaited(_pulse.repeat(reverse: true));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: AppLocalizations.of(context).loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 1,
              end: 0.55,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: GhostFade(child: widget.ghost),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when content failed to load. Calm on purpose: the data is still
/// on the device, and a retry almost always fixes it.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CentSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CategoryTile(
            icon: CentIcons.alert,
            tint: CentTint.neutral,
            size: 56,
          ),
          const SizedBox(height: CentSpace.lg),
          Text(
            l10n.loadFailedTitle,
            textAlign: TextAlign.center,
            style: CentType.title3.copyWith(color: c.ink),
          ),
          const SizedBox(height: CentSpace.sm),
          Text(
            l10n.loadFailedBody,
            textAlign: TextAlign.center,
            style: CentType.callout.copyWith(color: c.secondary),
          ),
          const SizedBox(height: CentSpace.xl - 4),
          CentButton(
            label: l10n.tryAgain,
            icon: CentIcons.refresh,
            style: CentButtonStyle.compactSecondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Places a state widget in a scroll view, [top] below the header.
Widget stateSliver(Widget child, {double top = CentSpace.lg}) => SliverPadding(
  padding: EdgeInsets.only(top: top),
  sliver: SliverToBoxAdapter(child: child),
);

/// What a screen shows until all of [values] have data: a [ghost] while
/// they load, or an error with [onRetry] if one failed. Null once every
/// value is ready, so callers fall through to their content.
List<Widget>? pendingSlivers(
  Iterable<AsyncValue<Object?>> values, {
  required Widget ghost,
  required VoidCallback onRetry,
}) {
  if (values.every((v) => v.hasValue)) return null;
  if (values.any((v) => v.hasError && !v.hasValue)) {
    return [stateSliver(ErrorState(onRetry: onRetry), top: CentSpace.huge)];
  }
  return [stateSliver(LoadingState(ghost: ghost))];
}
