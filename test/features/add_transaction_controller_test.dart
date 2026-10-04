import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/providers.dart';
import 'package:cent/features/add_transaction/add_transaction_controller.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  final now = DateTime(2026, 10, 4, 19, 30);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    await container.read(appStartupProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Keeps the auto-disposed controller alive for the whole test.
  AddTransactionController controller() {
    container.listen(addTransactionControllerProvider, (_, _) {});
    return container.read(addTransactionControllerProvider.notifier);
  }

  void typeAmount(AddTransactionController c, String keys) {
    for (final key in keys.split('')) {
      c.pressKey(key);
    }
  }

  Future<LedgerEntry> latest() =>
      (db.select(db.transactions)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingle();

  test('saves an expense as a negative amount', () async {
    final c = controller();
    await c.startNew();
    expect(c.canContinue, isFalse);

    typeAmount(c, '12.5');
    c.setTitle('  Bakery  ');
    await c.save();

    final saved = await latest();
    expect(saved.kind, TransactionKind.expense);
    expect(saved.amountMinor, -1250);
    expect(saved.title, 'Bakery');
    expect(saved.occurredAt, now);
  });

  test('falls back to the category name without a title', () async {
    final c = controller();
    await c.startNew(kind: TransactionKind.income);
    typeAmount(c, '100');
    await c.save();

    final saved = await latest();
    expect(saved.amountMinor, 10000);
    expect(saved.title, 'Salary');
  });

  test('switching kind picks a category of the matching kind', () async {
    final c = controller();
    await c.startNew();
    final expenseCategory = container
        .read(addTransactionControllerProvider)!
        .categoryId;

    c.setKind(TransactionKind.income);
    final incomeCategory = container
        .read(addTransactionControllerProvider)!
        .categoryId;
    expect(incomeCategory, isNot(expenseCategory));

    c.setKind(TransactionKind.transfer);
    expect(
      container.read(addTransactionControllerProvider)!.categoryId,
      isNull,
    );
  });

  test('edits an existing entry in place', () async {
    final original =
        await (db.select(db.transactions)
              ..where((t) => t.kind.equalsValue(TransactionKind.expense))
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingle();
    final c = controller();
    await c.startEdit(original.id);

    c.deleteKey();
    c.setTitle('Edited');
    await c.save();

    final edited = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(original.id))).getSingle();
    expect(edited.title, 'Edited');
    expect(edited.amountMinor.abs(), lessThan(original.amountMinor.abs()));
  });

  test('converts a transfer into another currency', () async {
    final accounts = await db.select(db.accounts).get();
    final main = accounts.firstWhere((a) => a.name == 'Main account');
    final trip = accounts.firstWhere((a) => a.name == 'Trip fund');

    final c = controller();
    await c.startNew(kind: TransactionKind.transfer);
    c.setAccount(main.id);
    c.setToAccount(trip.id);
    typeAmount(c, '250');

    final received = await c.received();
    expect(received!.minor, 29060);
    expect(received.currency.code, 'USD');

    await c.save();
    final incoming = await latest();
    expect(incoming.accountId, trip.id);
    expect(incoming.amountMinor, 29060);
  });

  test('a transfer to the same account cannot continue', () async {
    final c = controller();
    await c.startNew(kind: TransactionKind.transfer);
    final draft = container.read(addTransactionControllerProvider)!;
    typeAmount(c, '5');
    c.setToAccount(draft.accountId);
    expect(c.canContinue, isFalse);
  });
}
