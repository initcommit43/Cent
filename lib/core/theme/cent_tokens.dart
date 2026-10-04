/// Spacing, radius and size tokens from DESIGN.md, in logical points.
abstract final class CentSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 64;
  static const double screenMargin = 16;
  static const double screenMarginWide = 20;

  /// HIG switches to the wider margin on phones 400pt and up.
  static double margin(double screenWidth) =>
      screenWidth >= 400 ? screenMarginWide : screenMargin;
}

abstract final class CentRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double pill = 9999;
}

abstract final class CentSize {
  static const double touchTarget = 44;
  static const double button = 50;
  static const double buttonCompact = 36;
  static const double field = 48;
  static const double chip = 32;
  static const double row = 64;
  static const double tabBar = 49;
  static const double navBar = 44;
  static const double categoryTile = 40;
}
