import 'package:flutter/painting.dart';

/// Type scale from DESIGN.md, following the iOS text styles.
///
/// Colors are left unset so widgets pick them from [CentColors].
abstract final class CentType {
  static const family = 'HankenGrotesk';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    FontWeight weight,
    double lineHeight,
    double tracking, {
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
      letterSpacing: tracking,
      fontFeatures: tabular ? _tabular : null,
    );
  }

  static final displayHero = _style(
    48,
    FontWeight.w300,
    1.05,
    -0.96,
    tabular: true,
  );
  static final largeTitle = _style(34, FontWeight.w300, 1.1, -0.68);
  static final title1 = _style(28, FontWeight.w300, 1.12, -0.42);
  static final title2 = _style(22, FontWeight.w300, 1.15, -0.22);
  static final title3 = _style(20, FontWeight.w400, 1.25, -0.2);
  static final headline = _style(17, FontWeight.w500, 1.3, -0.17);
  static final body = _style(17, FontWeight.w400, 1.35, 0);
  static final bodyTabular = _style(
    17,
    FontWeight.w400,
    1.35,
    -0.34,
    tabular: true,
  );
  static final callout = _style(16, FontWeight.w400, 1.35, 0);
  static final subheadline = _style(15, FontWeight.w400, 1.35, 0);
  static final subheadlineTabular = _style(
    15,
    FontWeight.w400,
    1.35,
    -0.3,
    tabular: true,
  );
  static final footnote = _style(13, FontWeight.w400, 1.35, 0);
  static final caption1 = _style(
    12,
    FontWeight.w400,
    1.35,
    -0.24,
    tabular: true,
  );
  static final caption2 = _style(11, FontWeight.w500, 1.2, 0.2);
  static final buttonLarge = _style(17, FontWeight.w500, 1, 0);
  static final buttonSmall = _style(15, FontWeight.w500, 1, 0);
}
