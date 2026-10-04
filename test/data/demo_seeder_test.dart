import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/accounts_repository.dart';
import 'package:cent/data/demo_seeder.dart';
import 'package:cent/data/transactions_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 4, 19, 30);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DemoSeeder(db, now: now).seed();
  });

  tearDown(() => db.close());

  test('creates the expected accounts and nothing in the future', () async {
    final accounts = await AccountsRepository(db).watchAll().first;
    expect(accounts.map((a) => a.account.name), [
      'Main account',
      'Credit card',
      'Savings',
      'Trip fund',
      'Wallet',
    ]);

    final future = await (db.select(
      db.transactions,
    )..where((t) => t.occurredAt.isBiggerThanValue(now))).get();
    expect(future, isEmpty);
  });

  test('every transfer has a matching other half', () async {
    final transfers = await (db.select(
      db.transactions,
    )..where((t) => t.kind.equalsValue(TransactionKind.transfer))).get();
    expect(transfers, isNotEmpty);
    for (final t in transfers) {
      final peer = transfers.firstWhere((p) => p.id == t.transferPeerId);
      expect(peer.transferPeerId, t.id);
      expect(t.amountMinor.sign, -peer.amountMinor.sign);
    }
  });

  test('goals land on the amounts shown in the designs', () async {
    final rows = await db
        .customSelect(
          'SELECT g.name, SUM(c.amount_minor) AS saved FROM goals g '
          'JOIN goal_contributions c ON c.goal_id = g.id GROUP BY g.id',
        )
        .get();
    final saved = {
      for (final r in rows) r.read<String>('name'): r.read<int>('saved'),
    };
    expect(saved, {
      'Japan trip': 215000,
      'Emergency fund': 520000,
      'New laptop': 64000,
    });
  });

  test('is reproducible', () async {
    final first = await TransactionsRepository(db)
        .watchRange(DateTime(2026, 8), DateTime(2026, 11))
        .first;
    await DemoSeeder(db, now: now).seed();
    final second = await TransactionsRepository(db)
        .watchRange(DateTime(2026, 8), DateTime(2026, 11))
        .first;

    expect(
      second.map((e) => (e.entry.title, e.entry.amountMinor)),
      first.map((e) => (e.entry.title, e.entry.amountMinor)),
    );
  });
}
