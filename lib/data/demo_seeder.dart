import 'dart:math';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import 'default_categories.dart';
import 'settings_repository.dart';

/// Fills the database with three months of believable history ending at
/// [now]. Uses a fixed seed so screenshots and tests are reproducible.
class DemoSeeder {
  DemoSeeder(this._db, {DateTime? now, int seed = 7})
    : _now = now ?? DateTime.now(),
      _random = Random(seed);

  final AppDatabase _db;
  final DateTime _now;
  final Random _random;

  late final Map<String, int> _categoryIds;
  late final int _main, _card, _savings, _tripFund, _wallet;

  Future<void> seed() => _db.transaction(() async {
    await _clearAll();
    await _insertCategories();
    await _insertAccounts();
    await _insertRates();
    await _insertRecurring();
    await _insertDailySpending();
    await _insertTransfers();
    await _insertBudgets();
    await _insertGoals();
    await _insertSettings();
  });

  DateTime get _start => DateTime(_now.year, _now.month - 2);

  Future<void> _clearAll() async {
    for (final table in _db.allTables.toList().reversed) {
      await _db.delete(table).go();
    }
  }

  Future<void> _insertCategories() async {
    _categoryIds = {};
    for (var i = 0; i < defaultCategories.length; i++) {
      final c = defaultCategories[i];
      _categoryIds[c.name] = await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: c.name,
              icon: c.icon,
              tint: c.tint,
              kind: c.kind,
              sortOrder: Value(i),
            ),
          );
    }
  }

  Future<void> _insertAccounts() async {
    Future<int> account(
      String name,
      AccountType type,
      String currency,
      int opening,
      int order,
    ) => _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            currency: currency,
            openingBalanceMinor: Value(opening),
            sortOrder: Value(order),
            createdAt: Value(_start),
          ),
        );

    _main = await account(
      'Main account',
      AccountType.checking,
      'EUR',
      180000,
      0,
    );
    _card = await account('Credit card', AccountType.card, 'EUR', 0, 1);
    _savings = await account('Savings', AccountType.savings, 'EUR', 641760, 2);
    _tripFund = await account(
      'Trip fund',
      AccountType.savings,
      'USD',
      91000,
      3,
    );
    _wallet = await account('Wallet', AccountType.cash, 'EUR', 12000, 4);
  }

  Future<void> _insertRates() async {
    const rates = {
      'USD': '1.1624',
      'GBP': '0.8711',
      'SEK': '11.0215',
      'NOK': '11.6830',
      'DKK': '7.4612',
      'PLN': '4.2618',
      'CZK': '24.3850',
      'HUF': '391.42',
      'CAD': '1.6012',
      'AUD': '1.7495',
      'JPY': '172.45',
    };
    final asOf = DateTime(_now.year, _now.month, _now.day, 6);
    await _db.batch((b) {
      b.insertAll(_db.exchangeRates, [
        for (final e in rates.entries)
          ExchangeRatesCompanion.insert(
            base: 'EUR',
            quote: e.key,
            rate: e.value,
            asOf: asOf,
          ),
        ExchangeRatesCompanion.insert(
          base: 'EUR',
          quote: 'CHF',
          rate: '0.9350',
          asOf: asOf,
          isManual: const Value(true),
        ),
      ]);
    });
  }

  Future<void> _insertRecurring() async {
    final rules = [
      ('Salary', 284000, 3, _main, 'Salary', TransactionKind.income),
      ('Rent share', 21000, 1, _main, 'Home', TransactionKind.expense),
      ('Netflix', 1399, 2, _card, 'Subscriptions', TransactionKind.expense),
      ('Spotify', 1099, 3, _card, 'Subscriptions', TransactionKind.expense),
      ('Gym membership', 2990, 6, _main, 'Fitness', TransactionKind.expense),
      ('Phone plan', 1500, 8, _main, 'Utilities', TransactionKind.expense),
      ('Transit pass', 5100, 15, _main, 'Transport', TransactionKind.expense),
      ('Home insurance', 2450, 20, _main, 'Home', TransactionKind.expense),
      (
        'Cloud storage',
        299,
        28,
        _card,
        'Subscriptions',
        TransactionKind.expense,
      ),
    ];

    for (final (title, minor, day, accountId, category, kind) in rules) {
      final anchor = DateTime(_start.year, _start.month, day, 8);
      var due = anchor;
      final ruleId = await _db
          .into(_db.recurringRules)
          .insert(
            RecurringRulesCompanion.insert(
              accountId: accountId,
              categoryId: Value(_categoryIds[category]),
              kind: kind,
              amountMinor: minor,
              currency: 'EUR',
              title: title,
              frequency: Frequency.monthly,
              anchorDate: anchor,
              nextDue: anchor,
              reminderDaysBefore: const Value(1),
            ),
          );
      while (!due.isAfter(_now)) {
        await _entry(
          accountId,
          category,
          kind == TransactionKind.income ? minor : -minor,
          title,
          due,
          ruleId: ruleId,
        );
        due = DateTime(due.year, due.month + 1, day, 8);
      }
      await (_db.update(_db.recurringRules)..where((r) => r.id.equals(ruleId)))
          .write(RecurringRulesCompanion(nextDue: Value(due)));
    }
  }

  Future<void> _insertDailySpending() async {
    for (
      var day = _start;
      !day.isAfter(_now);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final isToday =
          day.year == _now.year &&
          day.month == _now.month &&
          day.day == _now.day;
      if (day.difference(_start).inDays % 3 == 1 || isToday) {
        await _spend(
          day,
          'Groceries',
          ['Billa', 'Hofer', 'Billa', 'Spar', 'Lidl'],
          1800,
          6200,
          _main,
          hour: 18,
        );
      }
      if (_chance(0.35)) {
        await _spend(
          day,
          'Eating out',
          [
            'Café Central',
            'Figlmüller',
            'Vapiano',
            'Bao Bar',
            'Naschmarkt Deli',
          ],
          740,
          2800,
          _pick([_main, _card]),
          hour: 13,
        );
      }
      if (_chance(0.3)) {
        await _spend(
          day,
          'Coffee',
          ['Coffee Pirates', 'Café Sperl', 'Kaffeemik'],
          320,
          580,
          _wallet,
          hour: 9,
        );
      }
      if (_chance(0.1)) {
        await _spend(
          day,
          'Transport',
          ['Wiener Linien', 'Taxi'],
          240,
          2200,
          _main,
          hour: 21,
        );
      }
      if (_chance(0.07)) {
        await _spend(
          day,
          'Shopping',
          ['Zara', 'Uniqlo', 'IKEA', 'Amazon'],
          1990,
          8900,
          _card,
          hour: 17,
        );
      }
      if (_chance(0.06)) {
        await _spend(
          day,
          'Health',
          ['dm', 'Bipa', 'Pharmacy'],
          590,
          2500,
          _main,
          hour: 16,
        );
      }
      if (_chance(0.06)) {
        await _spend(
          day,
          'Leisure',
          ['Cinema', 'Concert tickets', 'Museum'],
          1200,
          4500,
          _card,
          hour: 20,
        );
      }
    }
  }

  Future<void> _insertTransfers() async {
    for (
      var month = _start;
      !month.isAfter(_now);
      month = DateTime(month.year, month.month + 1)
    ) {
      final savingDay = DateTime(month.year, month.month, 4, 9);
      if (!savingDay.isAfter(_now)) {
        await _transfer(
          _main,
          _savings,
          30000,
          30000,
          'Monthly saving',
          savingDay,
        );
      }
      final payoffDay = DateTime(month.year, month.month, 15, 9);
      if (!payoffDay.isAfter(_now) && month != _start) {
        await _transfer(_main, _card, 25000, 25000, 'Card payment', payoffDay);
      }
    }
    final tripDay = DateTime(_now.year, _now.month - 1, 12, 10);
    await _transfer(_main, _tripFund, 25000, 29060, 'Trip savings', tripDay);
  }

  Future<void> _insertBudgets() async {
    const budgets = {
      'Groceries': 45000,
      'Eating out': 35000,
      'Home': 26000,
      'Transport': 12000,
      'Subscriptions': 10000,
      'Shopping': 15000,
    };
    await _db.batch((b) {
      b.insertAll(_db.budgets, [
        for (final e in budgets.entries)
          BudgetsCompanion.insert(
            categoryId: _categoryIds[e.key]!,
            amountMinor: e.value,
            period: BudgetPeriod.monthly,
            alertAtPercent: const Value(80),
          ),
      ]);
    });
  }

  Future<void> _insertGoals() async {
    Future<void> goal(
      String name,
      String icon,
      String tint,
      int target,
      DateTime? due,
      int starting,
      int monthly,
    ) async {
      final id = await _db
          .into(_db.goals)
          .insert(
            GoalsCompanion.insert(
              name: name,
              icon: icon,
              tint: tint,
              targetMinor: target,
              currency: 'EUR',
              targetDate: Value(due),
              sourceAccountId: Value(_main),
              createdAt: Value(_start),
            ),
          );
      await _contribute(id, starting, _start, note: 'Starting amount');
      for (
        var month = _start;
        !month.isAfter(_now);
        month = DateTime(month.year, month.month + 1)
      ) {
        await _contribute(id, monthly, DateTime(month.year, month.month, 1, 9));
      }
    }

    await goal(
      'Japan trip',
      'plane',
      'patina',
      400000,
      DateTime(_now.year + 1, 6),
      149500,
      18500,
    );
    await goal(
      'Emergency fund',
      'shield',
      'copper',
      900000,
      null,
      460000,
      20000,
    );
    await goal(
      'New laptop',
      'monitor',
      'brass',
      180000,
      DateTime(_now.year, _now.month + 5),
      34000,
      10000,
    );

    final japan = await (_db.select(
      _db.goals,
    )..where((g) => g.name.equals('Japan trip'))).getSingle();
    await _contribute(
      japan.id,
      10000,
      DateTime(_now.year, _now.month - 1, 14, 12),
      note: 'Birthday money',
    );
  }

  Future<void> _insertSettings() async {
    final settings = SettingsRepository(_db);
    await settings.write(SettingKeys.baseCurrency, 'EUR');
    await settings.writeBool(SettingKeys.demoData, value: true);
    await settings.writeBool(SettingKeys.onboardingDone, value: true);
    await settings.write(
      SettingKeys.ratesUpdatedAt,
      DateTime(_now.year, _now.month, _now.day, 6).toIso8601String(),
    );
  }

  Future<void> _spend(
    DateTime day,
    String category,
    List<String> merchants,
    int minMinor,
    int maxMinor,
    int accountId, {
    required int hour,
  }) async {
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      _random.nextInt(60),
    );
    if (at.isAfter(_now)) return;
    final minor = minMinor + _random.nextInt(maxMinor - minMinor);
    // Round to 5 cents so amounts look like real receipts.
    await _entry(
      accountId,
      category,
      -(minor - minor % 5),
      _pick(merchants),
      at,
    );
  }

  Future<void> _entry(
    int accountId,
    String category,
    int signedMinor,
    String title,
    DateTime at, {
    int? ruleId,
  }) async {
    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(_categoryIds[category]),
            kind: signedMinor < 0
                ? TransactionKind.expense
                : TransactionKind.income,
            amountMinor: signedMinor,
            currency: account.currency,
            title: title,
            occurredAt: at,
            recurringRuleId: Value(ruleId),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  }

  Future<void> _transfer(
    int from,
    int to,
    int sent,
    int received,
    String title,
    DateTime at,
  ) async {
    final accounts = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.isIn([from, to]))).get();
    String currencyOf(int id) =>
        accounts.firstWhere((a) => a.id == id).currency;
    final outId = await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: from,
            kind: TransactionKind.transfer,
            amountMinor: -sent,
            currency: currencyOf(from),
            title: title,
            occurredAt: at,
          ),
        );
    final inId = await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: to,
            kind: TransactionKind.transfer,
            amountMinor: received,
            currency: currencyOf(to),
            title: title,
            occurredAt: at,
            transferPeerId: Value(outId),
          ),
        );
    await (_db.update(_db.transactions)..where((t) => t.id.equals(outId)))
        .write(TransactionsCompanion(transferPeerId: Value(inId)));
  }

  Future<void> _contribute(
    int goalId,
    int minor,
    DateTime at, {
    String? note,
  }) async {
    if (at.isAfter(_now)) return;
    await _db
        .into(_db.goalContributions)
        .insert(
          GoalContributionsCompanion.insert(
            goalId: goalId,
            amountMinor: minor,
            fromAccountId: Value(_main),
            note: Value(note),
            occurredAt: at,
          ),
        );
  }

  bool _chance(double p) => _random.nextDouble() < p;

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];
}
