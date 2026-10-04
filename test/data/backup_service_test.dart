import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/accounts_repository.dart';
import 'package:cent/data/backup_service.dart';
import 'package:cent/data/demo_seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 4, 19, 30);
  late AppDatabase source;
  late AppDatabase target;

  setUp(() async {
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    await DemoSeeder(source, now: now).seed();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('a backup restores identical balances and links', () async {
    final json = await BackupService(source).exportJson(now);
    final info = BackupService(target).inspect(json);
    expect(info.exportedAt, now);

    await BackupService(target).importJson(json);

    Future<Map<String, int>> balances(AppDatabase db) async => {
      for (final a in await AccountsRepository(db).watchAll().first)
        a.account.name: a.balance.minor,
    };
    expect(await balances(target), await balances(source));

    final transfers = await (target.select(
      target.transactions,
    )..where((t) => t.transferPeerId.isNotNull())).get();
    expect(transfers, isNotEmpty);
    expect(
      (await target.select(target.recurringRules).get()).length,
      (await source.select(source.recurringRules).get()).length,
    );
    expect(
      info.transactions,
      (await target.select(target.transactions).get()).length,
    );
  });

  test('importing replaces existing data', () async {
    final json = await BackupService(source).exportJson(now);
    await DemoSeeder(target, now: now, seed: 99).seed();
    await BackupService(target).importJson(json);
    expect(
      (await target.select(target.transactions).get()).length,
      (await source.select(source.transactions).get()).length,
    );
  });

  test('rejects files that are not Cent backups', () {
    final service = BackupService(target);
    expect(
      () => service.inspect('nope'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => service.inspect('{"app":"other","version":1}'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('CSV quotes text with commas and uses a minus for expenses', () async {
    final csv = await BackupService(source).exportCsv();
    final lines = csv.trim().split('\n');
    expect(
      lines.first,
      'date,title,category,account,type,amount,currency,note',
    );
    expect(lines.skip(1).any((l) => l.contains(',expense,-')), isTrue);
  });
}
