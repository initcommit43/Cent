import 'dart:convert';

import 'package:cent/core/database/app_database.dart';
import 'package:cent/core/money/currency.dart';
import 'package:cent/core/money/exchange_rate.dart';
import 'package:cent/data/rates_repository.dart';
import 'package:cent/data/rates_service.dart';
import 'package:cent/data/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase db;
  late RatesRepository rates;
  late SettingsRepository settings;
  var requests = 0;
  final now = DateTime(2026, 10, 4, 9);

  RatesService service(http.Client client) => RatesService(
    rates: rates,
    settings: settings,
    client: client,
    clock: () => now,
  );

  final ok = MockClient((request) async {
    requests++;
    expect(request.url.host, 'api.frankfurter.dev');
    expect(request.url.queryParameters['base'], 'EUR');
    return http.Response(
      jsonEncode({
        'base': 'EUR',
        'rates': {'USD': 1.1225, 'GBP': 0.85033, 'JPY': 176.99, 'BRL': 5.861},
      }),
      200,
    );
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    rates = RatesRepository(db);
    settings = SettingsRepository(db);
    requests = 0;
  });

  tearDown(() => db.close());

  test('stores supported rates and skips the rest', () async {
    await service(ok).refresh(Currency.eur);

    final stored = await rates.watchFor(Currency.eur).first;
    expect(
      {for (final r in stored) r.quote: r.rate},
      {'USD': '1.1225', 'GBP': '0.85033', 'JPY': '176.99'},
    );
    expect(await service(ok).lastUpdated(), now);
  });

  test('does not refetch fresh rates', () async {
    await service(ok).refresh(Currency.eur);
    await service(ok).refreshIfStale(Currency.eur);
    expect(requests, 1);
  });

  test('keeps cached rates when offline', () async {
    await rates.saveFetched([
      ExchangeRate(base: Currency.eur, quote: Currency.usd, rate: '1.1624'),
    ], DateTime(2026, 10));

    final offline = MockClient((_) async => throw http.ClientException('off'));
    await service(offline).refreshIfStale(Currency.eur);

    final stored = await rates.watchFor(Currency.eur).first;
    expect(stored.single.rate, '1.1624');
  });
}
