import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'cent_colors.dart';
import 'cent_typography.dart';

abstract final class CentTheme {
  static ThemeData light() => _build(Brightness.light, CentColors.light);
  static ThemeData dark() => _build(Brightness.dark, CentColors.dark);

  static ThemeData _build(Brightness brightness, CentColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accentPatina,
      onSecondary: c.onPrimary,
      error: c.negative,
      onError: c.onPrimary,
      surface: c.canvas,
      onSurface: c.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: CentType.family,
      scaffoldBackgroundColor: c.canvasSoft,
      extensions: [c],
      // The app uses one iOS design language on every platform, so Android
      // gets Cupertino transitions and no Material ink effects.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: c.primaryText,
        scaffoldBackgroundColor: c.canvasSoft,
        barBackgroundColor: c.material,
        textTheme: CupertinoTextThemeData(
          primaryColor: c.primaryText,
          textStyle: CentType.body.copyWith(color: c.ink),
          actionTextStyle: CentType.body.copyWith(color: c.primaryText),
          navTitleTextStyle: CentType.headline.copyWith(color: c.ink),
          navLargeTitleTextStyle: CentType.largeTitle.copyWith(color: c.ink),
          navActionTextStyle: CentType.body.copyWith(color: c.primaryText),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: CentType.displayHero,
        headlineLarge: CentType.largeTitle,
        headlineMedium: CentType.title1,
        headlineSmall: CentType.title2,
        titleLarge: CentType.title3,
        titleMedium: CentType.headline,
        bodyLarge: CentType.body,
        bodyMedium: CentType.subheadline,
        bodySmall: CentType.footnote,
        labelLarge: CentType.buttonLarge,
        labelMedium: CentType.caption1,
        labelSmall: CentType.caption2,
      ).apply(bodyColor: c.ink, displayColor: c.ink),
    );
  }
}

extension CentThemeContext on BuildContext {
  CentColors get colors => Theme.of(this).extension<CentColors>()!;
}
