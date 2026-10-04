import 'package:cent/core/money/currency.dart';
import 'package:cent/core/money/exchange_rate.dart';
import 'package:cent/core/money/money.dart';
import 'package:cent/core/money/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('adds and subtracts in the same currency', () {
      const a = Money(1050, Currency.eur);
      const b = Money(-320, Currency.eur);
      expect(a + b, const Money(730, Currency.eur));
      expect(a - b, const Money(1370, Currency.eur));
    });

    test('refuses to mix currencies', () {
      expect(
        () => const Money(100, Currency.eur) + const Money(100, Currency.usd),
        throwsArgumentError,
      );
    });

    test('ratio of a budget', () {
      const spent = Money(41260, Currency.eur);
      const budget = Money(45000, Currency.eur);
      expect(spent.ratioOf(budget), closeTo(0.9169, 0.0001));
      expect(spent.ratioOf(const Money.zero(Currency.eur)), 0);
    });
  });

  group('formatMoney', () {
    test('uses a true minus sign for expenses', () {
      expect(formatMoney(const Money(-2450, Currency.eur)), '−€24.50');
    });

    test('shows plus for income when asked', () {
      expect(
        formatMoney(
          const Money(284000, Currency.eur),
          sign: SignDisplay.always,
        ),
        '+€2,840.00',
      );
    });

    test('never shows a sign on zero', () {
      expect(
        formatMoney(const Money.zero(Currency.eur), sign: SignDisplay.always),
        '€0.00',
      );
    });

    test('rounds to whole units on request', () {
      expect(formatMoney(const Money(9650, Currency.eur), whole: true), '€97');
    });

    test('respects currencies without minor units', () {
      expect(formatMoney(const Money(1500, Currency.jpy)), '¥1,500');
    });
  });

  group('ExchangeRate', () {
    final eurToUsd = ExchangeRate(
      base: Currency.eur,
      quote: Currency.usd,
      rate: '1.1624',
    );

    test('converts exactly with half-up rounding', () {
      // 250.00 EUR * 1.1624 = 290.60 USD
      expect(
        eurToUsd.convert(const Money(25000, Currency.eur)),
        const Money(29060, Currency.usd),
      );
      // 0.05 EUR * 1.1624 = 0.05812 USD -> 0.06
      expect(
        eurToUsd.convert(const Money(5, Currency.eur)),
        const Money(6, Currency.usd),
      );
    });

    test('rounds negative amounts away from zero', () {
      expect(
        eurToUsd.convert(const Money(-5, Currency.eur)),
        const Money(-6, Currency.usd),
      );
    });

    test('handles currencies with different minor units', () {
      final eurToJpy = ExchangeRate(
        base: Currency.eur,
        quote: Currency.jpy,
        rate: '172.45',
      );
      expect(
        eurToJpy.convert(const Money(1000, Currency.eur)),
        const Money(1725, Currency.jpy),
      );
    });

    test('inverts a rate', () {
      final usdToEur = eurToUsd.inverse();
      expect(usdToEur.base, Currency.usd);
      expect(usdToEur.rate, '0.860289');
      expect(
        usdToEur.convert(const Money(120000, Currency.usd)),
        const Money(103235, Currency.eur),
      );
    });

    test('rejects malformed rates', () {
      expect(
        () =>
            ExchangeRate(base: Currency.eur, quote: Currency.usd, rate: '1,2'),
        throwsFormatException,
      );
    });
  });
}
