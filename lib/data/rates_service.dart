import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/money/currency.dart';
import '../core/money/exchange_rate.dart';
import 'rates_repository.dart';
import 'settings_repository.dart';

/// Fetches daily ECB reference rates from Frankfurter (free, no API key)
/// and stores them for offline use. This is the app's only network call.
class RatesService {
  RatesService({
    required this._rates,
    required this._settings,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final RatesRepository _rates;
  final SettingsRepository _settings;
  final http.Client _client;
  final DateTime Function() _clock;

  /// ECB publishes once per working day, so refreshing more often is wasted.
  static const maxAge = Duration(hours: 12);

  static Uri endpoint(Currency base) =>
      Uri.https('api.frankfurter.dev', '/v1/latest', {
        'base': base.code,
        'symbols': Currency.supported
            .where((c) => c != base)
            .map((c) => c.code)
            .join(','),
      });

  Future<DateTime?> lastUpdated() async {
    final value = await _settings.read(SettingKeys.ratesUpdatedAt);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Refreshes when the stored rates are older than [maxAge]. Failures are
  /// swallowed: cached rates keep working offline.
  Future<void> refreshIfStale(Currency base) async {
    final updated = await lastUpdated();
    if (updated != null && _clock().difference(updated) < maxAge) return;
    try {
      await refresh(base);
    } on Exception {
      // Offline or the service is down; the cached rates stay in use.
    }
  }

  Future<void> refresh(Currency base) async {
    final response = await _client
        .get(endpoint(base))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Frankfurter returned ${response.statusCode}',
        response.request?.url,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = (body['rates'] as Map<String, dynamic>).entries
        .where((e) => Currency.supported.any((c) => c.code == e.key))
        .map(
          (e) => ExchangeRate(
            base: base,
            quote: Currency.of(e.key),
            rate: _decimal(e.value as num),
          ),
        );

    final now = _clock();
    await _rates.saveFetched(rates, now);
    await _settings.write(SettingKeys.ratesUpdatedAt, now.toIso8601String());
  }

  /// JSON numbers arrive as doubles; write them back as plain decimals,
  /// never in exponent notation.
  static String _decimal(num value) {
    final text = value.toString();
    if (!text.contains('e')) return text;
    return value
        .toStringAsFixed(10)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
