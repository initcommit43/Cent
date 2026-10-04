import 'package:drift/drift.dart';

enum AccountType { checking, savings, cash, card }

enum CategoryKind { expense, income }

enum TransactionKind { expense, income, transfer }

enum BudgetPeriod { weekly, monthly, yearly }

enum Frequency { weekly, monthly, yearly }

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// Lucide icon name, resolved to an IconData in the UI layer.
  TextColumn get icon => text()();

  /// One of the brand tints: copper, patina, brass, blush, neutral.
  TextColumn get tint => text()();
  TextColumn get kind => textEnum<CategoryKind>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Amounts are signed: expenses negative, income positive. A transfer is two
/// rows pointing at each other, money leaving one account and arriving in
/// the other, possibly in a different currency.
@DataClassName('LedgerEntry')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get kind => textEnum<TransactionKind>()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get transferPeerId => integer().nullable()();
  IntColumn get recurringRuleId =>
      integer().nullable().references(RecurringRules, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get period => textEnum<BudgetPeriod>()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  IntColumn get alertAtPercent => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, period},
  ];
}

@DataClassName('Goal')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text()();
  TextColumn get tint => text()();
  IntColumn get targetMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get sourceAccountId =>
      integer().nullable().references(Accounts, #id)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Money set aside for a goal. Tracked on its own and does not move money
/// between accounts.
@DataClassName('GoalContribution')
class GoalContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId =>
      integer().references(Goals, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer()();
  IntColumn get fromAccountId =>
      integer().nullable().references(Accounts, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
}

/// Template for repeating transactions. Due entries are created from it when
/// the app starts, so nothing runs in the background.
@DataClassName('RecurringRule')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get kind => textEnum<TransactionKind>()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  TextColumn get frequency => textEnum<Frequency>()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get anchorDate => dateTime()();
  DateTimeColumn get nextDue => dateTime()();
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
  IntColumn get reminderDaysBefore => integer().nullable()();
}

@DataClassName('StoredRate')
class ExchangeRates extends Table {
  TextColumn get base => text().withLength(min: 3, max: 3)();
  TextColumn get quote => text().withLength(min: 3, max: 3)();

  /// Decimal string, see ExchangeRate.
  TextColumn get rate => text()();
  DateTimeColumn get asOf => dateTime()();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {base, quote};
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
