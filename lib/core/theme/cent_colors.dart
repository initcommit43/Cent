import 'package:flutter/material.dart';

/// Semantic color tokens from DESIGN.md, resolved per brightness.
@immutable
class CentColors extends ThemeExtension<CentColors> {
  const CentColors({
    required this.canvasSoft,
    required this.canvas,
    required this.elevated,
    required this.cream,
    required this.header,
    required this.hero,
    required this.heroBorder,
    required this.primary,
    required this.primaryPress,
    required this.tag,
    required this.onDarkButton,
    required this.chipSelected,
    required this.material,
    required this.backdrop,
    required this.ink,
    required this.secondary,
    required this.mute,
    required this.placeholder,
    required this.onPrimary,
    required this.onChipSelected,
    required this.primaryText,
    required this.tagText,
    required this.onDarkButtonText,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.hairline,
    required this.input,
    required this.accentCopper,
    required this.accentPatina,
    required this.accentBrass,
    required this.accentBlush,
    required this.accentCopperSoft,
    required this.tintCopper,
    required this.tintPatina,
    required this.tintBrass,
    required this.tintBlush,
    required this.tintNeutral,
  });

  final Color canvasSoft;
  final Color canvas;
  final Color elevated;
  final Color cream;
  final Color header;
  final Color hero;
  final Color heroBorder;
  final Color primary;
  final Color primaryPress;
  final Color tag;
  final Color onDarkButton;
  final Color chipSelected;
  final Color material;
  final Color backdrop;
  final Color ink;
  final Color secondary;
  final Color mute;
  final Color placeholder;
  final Color onPrimary;
  final Color onChipSelected;
  final Color primaryText;
  final Color tagText;
  final Color onDarkButtonText;
  final Color positive;
  final Color negative;
  final Color warning;
  final Color hairline;
  final Color input;
  final Color accentCopper;
  final Color accentPatina;
  final Color accentBrass;
  final Color accentBlush;
  final Color accentCopperSoft;
  final Color tintCopper;
  final Color tintPatina;
  final Color tintBrass;
  final Color tintBlush;
  final Color tintNeutral;

  static const light = CentColors(
    canvasSoft: Color(0xFFF7F8F6),
    canvas: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    cream: Color(0xFFF6EADF),
    header: Color(0xFFF6EADF),
    hero: Color(0xFF10302B),
    heroBorder: Color(0xFF10302B),
    primary: Color(0xFFB4512B),
    primaryPress: Color(0xFF6E2E17),
    tag: Color(0xFFF4D3C2),
    onDarkButton: Color(0xFFFFFFFF),
    chipSelected: Color(0xFF16211E),
    material: Color(0xCCFFFFFF),
    backdrop: Color(0x4D16211E),
    ink: Color(0xFF16211E),
    secondary: Color(0xFF2F3A36),
    mute: Color(0xFF66726D),
    placeholder: Color(0xFF6B7570),
    onPrimary: Color(0xFFFFFFFF),
    onChipSelected: Color(0xFFFFFFFF),
    primaryText: Color(0xFFB4512B),
    tagText: Color(0xFF9A4222),
    onDarkButtonText: Color(0xFF10302B),
    positive: Color(0xFF1F7A67),
    negative: Color(0xFFC13A4A),
    warning: Color(0xFF8A6418),
    hairline: Color(0xFFE6E8E4),
    input: Color(0xFFB9C4BF),
    accentCopper: Color(0xFFB4512B),
    accentPatina: Color(0xFF2F9C85),
    accentBrass: Color(0xFFC9962E),
    accentBlush: Color(0xFFF2A48B),
    accentCopperSoft: Color(0xFFD27149),
    tintCopper: Color(0x29B4512B),
    tintPatina: Color(0x292F9C85),
    tintBrass: Color(0x2EC9962E),
    tintBlush: Color(0x4DF2A48B),
    tintNeutral: Color(0x1F66726D),
  );

  static const dark = CentColors(
    canvasSoft: Color(0xFF0C1513),
    canvas: Color(0xFF15211E),
    elevated: Color(0xFF1D2B27),
    cream: Color(0xFF1D2B27),
    header: Color(0xFF15211E),
    hero: Color(0xFF1D2B27),
    heroBorder: Color(0xFF2A3934),
    primary: Color(0xFFB4512B),
    primaryPress: Color(0xFF6E2E17),
    tag: Color(0xFFF4D3C2),
    onDarkButton: Color(0xFFFFFFFF),
    chipSelected: Color(0xFFEEF2F0),
    material: Color(0xCC15211E),
    backdrop: Color(0x4D16211E),
    ink: Color(0xFFEEF2F0),
    secondary: Color(0xFFC4CCC8),
    mute: Color(0xFF93A09A),
    placeholder: Color(0xFF93A09A),
    onPrimary: Color(0xFFFFFFFF),
    onChipSelected: Color(0xFF15211E),
    primaryText: Color(0xFFE08A63),
    tagText: Color(0xFF9A4222),
    onDarkButtonText: Color(0xFF10302B),
    positive: Color(0xFF5CC4AA),
    negative: Color(0xFFEF6F78),
    warning: Color(0xFFE3B45A),
    hairline: Color(0xFF2A3934),
    input: Color(0xFF93A09A),
    accentCopper: Color(0xFFE08A63),
    accentPatina: Color(0xFF5CC4AA),
    accentBrass: Color(0xFFE3B45A),
    accentBlush: Color(0xFFF2A48B),
    accentCopperSoft: Color(0xFFD27149),
    tintCopper: Color(0x38E08A63),
    tintPatina: Color(0x335CC4AA),
    tintBrass: Color(0x33E3B45A),
    tintBlush: Color(0x38F2A48B),
    tintNeutral: Color(0x2E93A09A),
  );

  @override
  CentColors copyWith() => this;

  @override
  CentColors lerp(CentColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CentColors(
      canvasSoft: l(canvasSoft, other.canvasSoft),
      canvas: l(canvas, other.canvas),
      elevated: l(elevated, other.elevated),
      cream: l(cream, other.cream),
      header: l(header, other.header),
      hero: l(hero, other.hero),
      heroBorder: l(heroBorder, other.heroBorder),
      primary: l(primary, other.primary),
      primaryPress: l(primaryPress, other.primaryPress),
      tag: l(tag, other.tag),
      onDarkButton: l(onDarkButton, other.onDarkButton),
      chipSelected: l(chipSelected, other.chipSelected),
      material: l(material, other.material),
      backdrop: l(backdrop, other.backdrop),
      ink: l(ink, other.ink),
      secondary: l(secondary, other.secondary),
      mute: l(mute, other.mute),
      placeholder: l(placeholder, other.placeholder),
      onPrimary: l(onPrimary, other.onPrimary),
      onChipSelected: l(onChipSelected, other.onChipSelected),
      primaryText: l(primaryText, other.primaryText),
      tagText: l(tagText, other.tagText),
      onDarkButtonText: l(onDarkButtonText, other.onDarkButtonText),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
      warning: l(warning, other.warning),
      hairline: l(hairline, other.hairline),
      input: l(input, other.input),
      accentCopper: l(accentCopper, other.accentCopper),
      accentPatina: l(accentPatina, other.accentPatina),
      accentBrass: l(accentBrass, other.accentBrass),
      accentBlush: l(accentBlush, other.accentBlush),
      accentCopperSoft: l(accentCopperSoft, other.accentCopperSoft),
      tintCopper: l(tintCopper, other.tintCopper),
      tintPatina: l(tintPatina, other.tintPatina),
      tintBrass: l(tintBrass, other.tintBrass),
      tintBlush: l(tintBlush, other.tintBlush),
      tintNeutral: l(tintNeutral, other.tintNeutral),
    );
  }
}
