import 'package:cent/core/database/app_database.dart';
import 'package:cent/core/money/currency.dart';
import 'package:cent/core/money/exchange_rate.dart';
import 'package:cent/core/money/money.dart';
import 'package:cent/data/accounts_repository.dart';
import 'package:cent/data/categories_repository.dart';
import 'package:cent/data/rates_repository.dart';
import 'package:cent/data/transactions_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;
  late RatesRepository rates;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountsRepository(db);
    categories = CategoriesRepository(db);
    transactions = TransactionsRepository(db);
    rates = RatesRepository(db);
  });

  tearDown(() => db.close());

  Future<int> groceries() => categories.create(
    name: 'Groceries',
    icon: 'shopping-cart',
    tint: 'copper',
    kind: CategoryKind.expense,
  );

  test('balance is opening balance plus signed entries', () async {
    final main = await accounts.create(
      name: 'Main',
      type: AccountType.checking,
      openingBalance: const Money(100000, Currency.eur),
    );
    final cat = await groceries();

    await transactions.add(
      kind: TransactionKind.expense,
      accountId: main,
      categoryId: cat,
      amount: const Money(3680, Currency.eur),
      title: 'Billa',
      occurredAt: DateTime(2026, 10, 4),
    );
    await transactions.add(
      kind: TransactionKind.income,
      accountId: main,
      categoryId: null,
      amount: const Money(284000, Currency.eur),
      title: 'Salary',
      occurredAt: DateTime(2026, 10, 3),
    );

    final balance = (await accounts.watch(main).first).balance;
    expect(balance, const Money(380320, Currency.eur));
  });

  test('daily balances walk back from today', () async {
    final main = await accounts.create(
      name: 'Main',
      type: AccountType.checking,
      openingBalance: const Money(10000, Currency.eur),
    );
    final cat = await groceries();
    Future<void> spend(int minor, DateTime at) => transactions.add(
      kind: TransactionKind.expense,
      accountId: main,
      categoryId: cat,
      amount: Money(minor, Currency.eur),
      title: 'Shop',
      occurredAt: at,
    );
    await spend(1000, DateTime(2026, 10, 2, 12));
    await spend(500, DateTime(2026, 10, 4, 9));

    final balances = await accounts
        .watchDailyBalances(main, DateTime(2026, 10), DateTime(2026, 10, 4))
        .first;
    expect(balances, [10000, 9000, 9000, 8500]);
  });

  test('a transfer moves money and deletes as a pair', () async {
    final main = await accounts.create(
      name: 'Main',
      type: AccountType.checking,
      openingBalance: const Money(50000, Currency.eur),
    );
    final trip = await accounts.create(
      name: 'Trip fund',
      type: AccountType.savings,
      openingBalance: const Money.zero(Currency.usd),
    );

    await transactions.addTransfer(
      fromAccountId: main,
      toAccountId: trip,
      sent: const Money(25000, Currency.eur),
      received: const Money(29060, Currency.usd),
      title: 'Trip savings',
      occurredAt: DateTime(2026, 10),
    );

    final all = await accounts.watchAll().first;
    expect(all[0].balance, const Money(25000, Currency.eur));
    expect(all[1].balance, const Money(29060, Currency.usd));

    final outgoing = (await transactions.watchForAccount(main).first).single;
    await transactions.delete(outgoing.entry.id);

    final after = await accounts.watchAll().first;
    expect(after[0].balance, const Money(50000, Currency.eur));
    expect(after[1].balance, const Money.zero(Currency.usd));
  });

  test('filters by month, kind and search text', () async {
    final main = await accounts.create(
      name: 'Main',
      type: AccountType.checking,
      openingBalance: const Money.zero(Currency.eur),
    );
    final cat = await groceries();
    Future<void> spend(String title, DateTime at) => transactions.add(
      kind: TransactionKind.expense,
      accountId: main,
      categoryId: cat,
      amount: const Money(1000, Currency.eur),
      title: title,
      occurredAt: at,
    );

    await spend('Billa', DateTime(2026, 10, 2));
    await spend('Hofer', DateTime(2026, 10, 3));
    await spend('Billa', DateTime(2026, 9, 28));

    final october = await transactions
        .watchRange(DateTime(2026, 10), DateTime(2026, 11))
        .first;
    expect(october.map((e) => e.entry.title), ['Hofer', 'Billa']);

    final search = await transactions
        .watchSearch(const EntryFilter(query: 'bil'))
        .first;
    expect(search, hasLength(2));

    final byCategory = await transactions
        .watchSearch(const EntryFilter(query: 'groc'))
        .first;
    expect(byCategory, hasLength(3));

    final income = await transactions
        .watchSearch(const EntryFilter(kinds: {TransactionKind.income}))
        .first;
    expect(income, isEmpty);
  });

  test('converter routes through the base currency', () async {
    await rates.saveFetched([
      ExchangeRate(base: Currency.eur, quote: Currency.usd, rate: '1.1624'),
      ExchangeRate(base: Currency.eur, quote: Currency.gbp, rate: '0.8711'),
    ], DateTime(2026, 10, 4));

    final converter = await rates.watchConverter(Currency.eur).first;
    expect(
      converter.convert(const Money(120000, Currency.usd), Currency.eur),
      const Money(103235, Currency.eur),
    );
    expect(
      converter.convert(const Money(10000, Currency.usd), Currency.gbp),
      const Money(7494, Currency.gbp),
    );
  });

  test('fetched rates never overwrite manual ones', () async {
    await rates.setManual(
      ExchangeRate(base: Currency.eur, quote: Currency.chf, rate: '0.9350'),
    );
    await rates.saveFetched([
      ExchangeRate(base: Currency.eur, quote: Currency.chf, rate: '0.9412'),
    ], DateTime(2026, 10, 4));

    final stored = await rates.watchFor(Currency.eur).first;
    expect(stored.single.rate, '0.9350');
    expect(stored.single.isManual, isTrue);
  });
}
