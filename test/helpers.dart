import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/providers.dart';
import 'package:cent/data/rates_service.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Overrides for an app wired to [db] at a fixed [now], fully offline so no
/// test depends on the network.
List<Override> testOverrides(AppDatabase db, DateTime now) => [
  databaseProvider.overrideWithValue(db),
  clockProvider.overrideWithValue(() => now),
  ratesServiceProvider.overrideWith(
    (ref) => RatesService(
      rates: ref.watch(ratesRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
      clock: () => now,
      client: MockClient((_) async => throw http.ClientException('offline')),
    ),
  ),
];
