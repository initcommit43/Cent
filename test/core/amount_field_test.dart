import 'package:cent/core/money/currency.dart';
import 'package:cent/core/widgets/amount_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses typed amounts into minor units', () {
    expect(parseAmountMinor('1,200.5', Currency.eur), 120050);
    expect(parseAmountMinor('', Currency.eur), 0);
    expect(parseAmountMinor('12.345', Currency.eur), isNull);
    expect(parseAmountMinor('1500', Currency.jpy), 1500);
  });

  test('negative amounts only where allowed', () {
    expect(parseAmountMinor('-312.4', Currency.eur), isNull);
    expect(
      parseAmountMinor('-312.4', Currency.eur, allowNegative: true),
      -31240,
    );
  });

  test('round-trips through the input text', () {
    expect(formatAmountInput(-31240, Currency.eur), '-312.40');
    expect(formatAmountInput(180000, Currency.eur), '1800');
    expect(
      parseAmountMinor(formatAmountInput(1205, Currency.eur), Currency.eur),
      1205,
    );
  });
}
