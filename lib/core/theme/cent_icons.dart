import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'cent_colors.dart';

/// Lucide icons at the 1.5pt stroke weight the design uses, looked up by
/// the names stored in the database.
abstract final class CentIcons {
  static const _byName = <String, IconData>{
    'shopping-cart': LucideIcons.shoppingCart300,
    'utensils': LucideIcons.utensils300,
    'coffee': LucideIcons.coffee300,
    'bus': LucideIcons.bus300,
    'shirt': LucideIcons.shirt300,
    'house': LucideIcons.house300,
    'smartphone': LucideIcons.smartphone300,
    'heart-pulse': LucideIcons.heartPulse300,
    'film': LucideIcons.film300,
    'plane': LucideIcons.plane300,
    'graduation-cap': LucideIcons.graduationCap300,
    'dumbbell': LucideIcons.dumbbell300,
    'gift': LucideIcons.gift300,
    'zap': LucideIcons.zap300,
    'ellipsis': LucideIcons.ellipsis300,
    'briefcase': LucideIcons.briefcase300,
    'piggy-bank': LucideIcons.piggyBank300,
    'shield': LucideIcons.shield300,
    'monitor': LucideIcons.monitor300,
    'receipt': LucideIcons.receipt300,
    'graduation': LucideIcons.graduationCap300,
    'car': LucideIcons.car300,
    'baby': LucideIcons.baby300,
    'heart': LucideIcons.heart300,
    'music': LucideIcons.music300,
  };

  static IconData named(String name) => _byName[name] ?? LucideIcons.receipt300;

  static const transfer = LucideIcons.arrowLeftRight300;
  static const search = LucideIcons.search300;
  static const filter = LucideIcons.slidersHorizontal300;
  static const add = LucideIcons.plus300;
  static const settings = LucideIcons.settings300;
  static const back = LucideIcons.chevronLeft300;
  static const forward = LucideIcons.chevronRight300;
  static const clear = LucideIcons.x300;
  static const delete = LucideIcons.trash2300;
  static const check = LucideIcons.check300;
  static const backspace = LucideIcons.delete300;
  static const chevronDown = LucideIcons.chevronDown300;
  static const calendar = LucideIcons.calendar300;
  static const target = LucideIcons.target300;
  static const globe = LucideIcons.globe300;
  static const info = LucideIcons.info300;
  static const lock = LucideIcons.lock300;
  static const faceId = LucideIcons.scanFace300;
  static const upload = LucideIcons.upload300;
  static const download = LucideIcons.download300;
  static const file = LucideIcons.fileText300;
  static const refresh = LucideIcons.refreshCw300;
  static const palette = LucideIcons.palette300;
  static const tag = LucideIcons.tag300;
  static const grip = LucideIcons.gripVertical300;
  static const eyeOff = LucideIcons.eyeOff300;
  static const bank = LucideIcons.landmark300;
  static const chart = LucideIcons.chartPie300;
  static const repeat = LucideIcons.repeat300;
  static const pause = LucideIcons.pause300;
  static const play = LucideIcons.play300;
  static const alert = LucideIcons.circleAlert300;
  static const up = LucideIcons.arrowUpRight300;
  static const down = LucideIcons.arrowDownLeft300;
  static const checking = LucideIcons.landmark300;
  static const savings = LucideIcons.piggyBank300;
  static const cash = LucideIcons.banknote300;
  static const card = LucideIcons.creditCard300;
}

/// One of the brand tints a category or account can use.
enum CentTint {
  copper,
  patina,
  brass,
  blush,
  neutral;

  static CentTint parse(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => neutral);

  Color background(CentColors c) => switch (this) {
    copper => c.tintCopper,
    patina => c.tintPatina,
    brass => c.tintBrass,
    blush => c.tintBlush,
    neutral => c.tintNeutral,
  };

  Color foreground(CentColors c) => switch (this) {
    copper => c.primaryText,
    patina => c.accentPatina,
    brass => c.accentBrass,
    blush => c.accentCopperSoft,
    neutral => c.ink,
  };
}
