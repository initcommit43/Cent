import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import '../core/money/exchange_rate.dart';
import '../core/money/money.dart';

/// Converts between currencies using the stored rates.
class CurrencyConverter {
  CurrencyConverter(this.base, Iterable<ExchangeRate> rates)
    : _fromBase = {
        for (final r in rates)
          if (r.base == base) r.quote: r,
      };

  final Currency base;
  final Map<Currency, ExchangeRate> _fromBase;

  bool canConvert(Currency from, Currency to) =>
      from == to ||
      (from == base || _fromBase.containsKey(from)) &&
          (to == base || _fromBase.containsKey(to));

  /// Routes through the base currency when neither side is the base.
  Money convert(Money amount, Currency to) {
    if (amount.currency == to) return amount;
    final inBase = amount.currency == base
        ? amount
        : _rate(amount.currency).inverse().convert(amount);
    return to == base ? inBase : _rate(to).convert(inBase);
  }

  ExchangeRate _rate(Currency quote) =>
      _fromBase[quote] ??
      (throw StateError('No rate for ${base.code} → ${quote.code}'));
}

class RatesRepository {
  RatesRepository(this._db);

  final AppDatabase _db;

  Stream<List<StoredRate>> watchFor(Currency base) => (_db.select(
    _db.exchangeRates,
  )..where((r) => r.base.equals(base.code))).watch();

  Stream<CurrencyConverter> watchConverter(Currency base) =>
      watchFor(base)
          .map((rows) => CurrencyConverter(base, rows.map(toExchangeRate)));

  /// Stores fetched rates without overwriting ones the user set by hand.
  Future<void> saveFetched(Iterable<ExchangeRate> rates, DateTime asOf) =>
      _db.transaction(() async {
        for (final rate in rates) {
          final existing =
              await (_db.select(_db.exchangeRates)..where(
                    (r) =>
                        r.base.equals(rate.base.code) &
                        r.quote.equals(rate.quote.code),
                  ))
                  .getSingleOrNull();
          if (existing?.isManual ?? false) continue;
          await _db
              .into(_db.exchangeRates)
              .insertOnConflictUpdate(_companion(rate, asOf, manual: false));
        }
      });

  Future<void> setManual(ExchangeRate rate) => _db
      .into(_db.exchangeRates)
      .insertOnConflictUpdate(_companion(rate, DateTime.now(), manual: true));

  Future<void> clearManual(Currency base, Currency quote) =>
      (_db.update(_db.exchangeRates)..where(
            (r) => r.base.equals(base.code) & r.quote.equals(quote.code),
          ))
          .write(const ExchangeRatesCompanion(isManual: Value(false)));

  static ExchangeRate toExchangeRate(StoredRate row) => ExchangeRate(
    base: Currency.of(row.base),
    quote: Currency.of(row.quote),
    rate: row.rate,
  );

  ExchangeRatesCompanion _companion(
    ExchangeRate rate,
    DateTime asOf, {
    required bool manual,
  }) => ExchangeRatesCompanion.insert(
    base: rate.base.code,
    quote: rate.quote.code,
    rate: rate.rate,
    asOf: asOf,
    isManual: Value(manual),
  );
}
