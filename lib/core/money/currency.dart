import 'package:flutter/foundation.dart';

@immutable
class Currency {
  const Currency(this.code, this.symbol, this.name, {this.decimals = 2});

  final String code;
  final String symbol;
  final String name;

  /// Number of minor-unit digits (cents). JPY has none.
  final int decimals;

  static const eur = Currency('EUR', '€', 'Euro');
  static const usd = Currency('USD', r'$', 'US dollar');
  static const gbp = Currency('GBP', '£', 'British pound');
  static const chf = Currency('CHF', 'Fr', 'Swiss franc');
  static const sek = Currency('SEK', 'kr', 'Swedish krona');
  static const nok = Currency('NOK', 'kr', 'Norwegian krone');
  static const dkk = Currency('DKK', 'kr', 'Danish krone');
  static const pln = Currency('PLN', 'zł', 'Polish złoty');
  static const czk = Currency('CZK', 'Kč', 'Czech koruna');
  static const huf = Currency('HUF', 'Ft', 'Hungarian forint');
  static const cad = Currency('CAD', r'CA$', 'Canadian dollar');
  static const aud = Currency('AUD', r'A$', 'Australian dollar');
  static const jpy = Currency('JPY', '¥', 'Japanese yen', decimals: 0);

  /// Currencies Frankfurter publishes rates for that Cent offers.
  static const supported = [
    eur, usd, gbp, chf, sek, nok, dkk, pln, czk, huf, cad, aud, jpy, //
  ];

  static Currency of(String code) => supported.firstWhere(
    (c) => c.code == code,
    orElse: () => throw ArgumentError.value(code, 'code', 'Unsupported'),
  );

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
