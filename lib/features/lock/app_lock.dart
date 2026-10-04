import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';

final localAuthProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);

final appLockProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appLock)
      .map((v) => v == 'true'),
);

final lockAfterProvider = StreamProvider<Duration>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appLockAfterSeconds)
      .map((v) => Duration(seconds: int.tryParse(v ?? '') ?? 0)),
);

final blurInSwitcherProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.blurInSwitcher)
      .map((v) => v != 'false'),
);

/// Whether the device offers Face ID, for wording only; everything else
/// says "app lock".
final usesFaceIdProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isIOS) return false;
  try {
    final types = await ref.read(localAuthProvider).getAvailableBiometrics();
    return types.contains(BiometricType.face);
  } on Exception {
    return false;
  }
});

/// Asks for biometrics or the device passcode. False when cancelled or
/// when the device has no screen lock.
Future<bool> authenticate(WidgetRef ref, String reason) async {
  final auth = ref.read(localAuthProvider);
  try {
    if (!await auth.isDeviceSupported()) return false;
    return await auth.authenticate(
      localizedReason: reason,
      persistAcrossBackgrounding: true,
    );
  } on Exception {
    return false;
  }
}

/// Turns app lock on or off. Turning it on asks once first, so nobody
/// locks themselves out of a phone without a screen lock.
Future<void> setAppLock(
  BuildContext context,
  WidgetRef ref, {
  required bool on,
}) async {
  final l10n = AppLocalizations.of(context);
  if (on) {
    final supported = await ref
        .read(localAuthProvider)
        .isDeviceSupported()
        .catchError((Object _) => false);
    if (!supported) {
      if (context.mounted) await showNotice(context, l10n.lockUnavailable);
      return;
    }
    if (!await authenticate(ref, l10n.unlockReason)) return;
  }
  unawaited(HapticFeedback.selectionClick());
  await ref
      .read(settingsRepositoryProvider)
      .writeBool(SettingKeys.appLock, value: on);
}

/// Covers the app with a lock screen when app lock is on, and blurs it
/// while the app is in the switcher.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool? _locked;
  bool _obscured = false;
  bool _authenticating = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_lockOnLaunch());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Read directly so the first frame never shows balances before the
  // setting has loaded.
  Future<void> _lockOnLaunch() async {
    final enabled = await ref
        .read(settingsRepositoryProvider)
        .readBool(SettingKeys.appLock);
    if (!mounted) return;
    setState(() => _locked = enabled);
    if (enabled) unawaited(_unlock());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The system prompt itself takes focus; that is not leaving the app.
    if (_authenticating) return;
    switch (state) {
      case AppLifecycleState.inactive || AppLifecycleState.hidden:
        if (ref.read(blurInSwitcherProvider).value ?? true) {
          setState(() => _obscured = true);
        }
      case AppLifecycleState.paused:
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        final enabled = ref.read(appLockProvider).value ?? false;
        final after = ref.read(lockAfterProvider).value ?? Duration.zero;
        final relock =
            enabled &&
            _locked == false &&
            leftAt != null &&
            DateTime.now().difference(leftAt) >= after;
        setState(() {
          _obscured = false;
          if (relock) _locked = true;
        });
        if (relock) unawaited(_unlock());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await authenticate(
      ref,
      AppLocalizations.of(context).unlockReason,
    );
    _authenticating = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the settings streams live for the lifecycle handler above.
    ref
      ..watch(appLockProvider)
      ..watch(lockAfterProvider)
      ..watch(blurInSwitcherProvider);
    final locked = _locked;
    if (locked == null) {
      return ColoredBox(color: context.colors.canvasSoft);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: locked, child: widget.child),
        if (_obscured && !locked)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: ColoredBox(
              color: context.colors.canvasSoft.withValues(alpha: 0.5),
            ),
          ),
        if (locked) _LockScreen(onUnlock: () => unawaited(_unlock())),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: c.header,
      child: SafeArea(
        minimum: const EdgeInsets.all(CentSpace.xl),
        child: Column(
          children: [
            const Spacer(flex: 3),
            const AppIcon(),
            const SizedBox(height: CentSpace.lg),
            Text(
              l10n.lockedTitle,
              style: CentType.title2.copyWith(color: c.ink),
            ),
            const Spacer(flex: 4),
            CentButton(label: l10n.unlock, expand: true, onPressed: onUnlock),
          ],
        ),
      ),
    );
  }
}
