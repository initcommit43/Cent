import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'money.dart';

/// U+2212. Typographic minus, wider than a hyphen and aligned with `+`.
const minusSign = '−';

enum SignDisplay {
  /// `€12.50` or `−€12.50`.
  auto,

  /// `+€12.50` or `−€12.50`, for income and expense rows.
  always,

  /// `€12.50` regardless of sign.
  never,
}

String formatMoney(
  Money money, {
  SignDisplay sign = SignDisplay.auto,
  String? locale,

  /// Rounds to whole units, for chart labels where cents are noise.
  bool whole = false,
}) {
  final format = NumberFormat.currency(
    locale: locale ?? 'en_US',
    symbol: money.currency.symbol,
    decimalDigits: whole ? 0 : money.currency.decimals,
  );
  // Doubles are fine here: this is display only, never arithmetic.
  final body = format.format(
    money.minor.abs() / math.pow(10, money.currency.decimals),
  );

  final prefix = switch (sign) {
    SignDisplay.never => '',
    _ when money.isNegative => minusSign,
    SignDisplay.always when !money.isZero => '+',
    _ => '',
  };
  return '$prefix$body';
}
