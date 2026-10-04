import 'package:cent/core/money/currency.dart';
import 'package:cent/features/add_transaction/amount_input.dart';
import 'package:flutter_test/flutter_test.dart';

AmountInput type(String keys, {Currency currency = Currency.eur}) {
  var input = const AmountInput();
  for (final key in keys.split('')) {
    input = input.press(key, currency);
  }
  return input;
}

void main() {
  test('replaces the leading zero', () {
    expect(type('36').text, '36');
  });

  test('keeps a trailing decimal point while typing', () {
    expect(type('12.').text, '12.');
    expect(type('12.').toMinor(Currency.eur), 1200);
  });

  test('allows at most two decimals', () {
    expect(type('36.805').text, '36.80');
    expect(type('36.805').toMinor(Currency.eur), 3680);
  });

  test('ignores a second decimal point', () {
    expect(type('1.2.3').text, '1.23');
  });

  test('ignores decimals for currencies without minor units', () {
    final input = type('1500.5', currency: Currency.jpy);
    expect(input.text, '15005');
    expect(input.toMinor(Currency.jpy), 15005);
  });

  test('caps the whole part at seven digits', () {
    expect(type('123456789').text, '1234567');
  });

  test('delete steps back to zero', () {
    expect(type('7').delete().text, '0');
    expect(type('12.5').delete().text, '12.');
  });

  test('round-trips an existing amount', () {
    expect(AmountInput.fromMinor(-3680, Currency.eur).text, '36.80');
    expect(AmountInput.fromMinor(284000, Currency.eur).text, '2840');
    expect(AmountInput.fromMinor(1205, Currency.eur).text, '12.05');
  });

  test('groups thousands for display', () {
    expect(type('1234567.5').display, '1,234,567.5');
  });
}
