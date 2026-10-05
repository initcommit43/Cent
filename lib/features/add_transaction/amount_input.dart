import 'package:flutter/foundation.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';

/// What the user has typed on the amount keypad, kept as text so input like
/// "12." or "12.5" displays exactly as typed.
@immutable
class AmountInput {
  const AmountInput([this.text = '0']);

  /// Builds the input from an existing amount, for editing.
  factory AmountInput.fromMinor(int minor, Currency currency) {
    if (currency.decimals == 0) return AmountInput('${minor.abs()}');
    final whole = minor.abs() ~/ 100;
    final cents = minor.abs() % 100;
    return AmountInput(
      cents == 0 ? '$whole' : '$whole.${cents.toString().padLeft(2, '0')}',
    );
  }

  final String text;

  /// Ten million minus a cent is plenty for a personal tracker.
  static const _maxWholeDigits = 7;

  static const decimalKey = '.';

  bool get isZero => toMinor(Currency.eur) == 0;

  AmountInput press(String key, Currency currency) {
    if (key == decimalKey) {
      if (currency.decimals == 0 || text.contains('.')) return this;
      return AmountInput('$text.');
    }
    assert(RegExp(r'^\d$').hasMatch(key), 'Keys are single digits');

    final dot = text.indexOf('.');
    if (dot != -1 && text.length - dot - 1 >= currency.decimals) return this;
    if (dot == -1 && text.length >= _maxWholeDigits && text != '0') return this;
    return AmountInput(text == '0' ? key : '$text$key');
  }

  AmountInput delete() => text.length <= 1
      ? const AmountInput()
      : AmountInput(text.substring(0, text.length - 1));

  int toMinor(Currency currency) {
    final parts = text.split('.');
    final whole = int.parse(parts[0]);
    if (currency.decimals == 0) return whole;
    final fraction = (parts.length > 1 ? parts[1] : '').padRight(2, '0');
    return whole * 100 + int.parse(fraction.substring(0, 2));
  }

  Money toMoney(Currency currency) => Money(toMinor(currency), currency);

  /// Adds thousands separators to the whole part, keeping typed decimals.
  String get display {
    final parts = text.split('.');
    final grouped = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }

  @override
  bool operator ==(Object other) => other is AmountInput && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
