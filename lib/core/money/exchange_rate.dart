import 'package:flutter/foundation.dart';

import 'currency.dart';
import 'money.dart';

/// `1 base = rate quote`, with the rate kept as a decimal string so
/// conversions stay exact.
@immutable
class ExchangeRate {
  ExchangeRate({required this.base, required this.quote, required String rate})
    : rate = rate.trim() {
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(this.rate)) {
      throw FormatException('Invalid rate', rate);
    }
  }

  final Currency base;
  final Currency quote;
  final String rate;

  /// Converts [amount] from [base] to [quote], rounding half away from zero.
  Money convert(Money amount) {
    if (amount.currency != base) {
      throw ArgumentError('Expected ${base.code}, got ${amount.currency}');
    }
    final parts = rate.split('.');
    final fraction = parts.length > 1 ? parts[1] : '';
    final rateScaled = BigInt.parse(parts[0] + fraction);

    // minor_quote = minor_base * rate * 10^quoteDecimals / 10^baseDecimals
    final numerator =
        BigInt.from(amount.minor) * rateScaled * _pow10(quote.decimals);
    final denominator = _pow10(fraction.length + base.decimals);

    return Money(_divideRounded(numerator, denominator).toInt(), quote);
  }

  ExchangeRate inverse({int precision = 6}) {
    final parts = rate.split('.');
    final fraction = parts.length > 1 ? parts[1] : '';
    final rateScaled = BigInt.parse(parts[0] + fraction);
    final scaled = _divideRounded(
      _pow10(fraction.length + precision),
      rateScaled,
    );
    final digits = scaled.toString().padLeft(precision + 1, '0');
    final whole = digits.substring(0, digits.length - precision);
    final frac = digits.substring(digits.length - precision);
    return ExchangeRate(base: quote, quote: base, rate: '$whole.$frac');
  }

  static BigInt _pow10(int exponent) => BigInt.from(10).pow(exponent);

  static BigInt _divideRounded(BigInt numerator, BigInt denominator) {
    final negative = numerator.isNegative != denominator.isNegative;
    final n = numerator.abs();
    final d = denominator.abs();
    final rounded = (n + d ~/ BigInt.two) ~/ d;
    return negative ? -rounded : rounded;
  }
}
