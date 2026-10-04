import 'package:flutter/foundation.dart';

import 'currency.dart';

/// An amount in a currency's minor units. Never use doubles for money.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);

  const Money.zero(this.currency) : minor = 0;

  final int minor;
  final Currency currency;

  bool get isNegative => minor < 0;
  bool get isZero => minor == 0;

  Money abs() => Money(minor.abs(), currency);

  Money operator -() => Money(-minor, currency);

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(minor - other.minor, currency);
  }

  /// Share of [total] as a ratio, for progress bars and percentages.
  double ratioOf(Money total) {
    _checkSameCurrency(total);
    return total.isZero ? 0 : minor / total.minor;
  }

  void _checkSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Cannot combine ${currency.code} with ${other.currency.code}. '
        'Convert first.',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _checkSameCurrency(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => '$minor ${currency.code}';
}
