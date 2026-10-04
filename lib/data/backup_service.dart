import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Summary of a backup file, shown before it replaces anything.
class BackupInfo {
  const BackupInfo({required this.exportedAt, required this.transactions});

  final DateTime exportedAt;
  final int transactions;
}

/// Reads and writes `.cent` backups: every table as JSON, so moving to a
/// new phone keeps ids, links between transfers and recurring history.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const formatVersion = 1;
  static const _app = 'cent';

  Future<String> exportJson(DateTime now) async {
    Future<List<Map<String, Object?>>> rows<T extends Table, D>(
      TableInfo<T, D> table,
    ) async => [
      for (final row in await _db.select(table).get())
        (row as DataClass).toJson(),
    ];

    final payload = {
      'app': _app,
      'version': formatVersion,
      'exportedAt': now.toIso8601String(),
      'data': {
        'categories': await rows(_db.categories),
        'accounts': await rows(_db.accounts),
        'recurringRules': await rows(_db.recurringRules),
        'transactions': await rows(_db.transactions),
        'budgets': await rows(_db.budgets),
        'goals': await rows(_db.goals),
        'goalContributions': await rows(_db.goalContributions),
        'exchangeRates': await rows(_db.exchangeRates),
        'settings': await rows(_db.settings),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Validates [json] without touching the database.
  BackupInfo inspect(String json) {
    final data = _parse(json);
    return BackupInfo(
      exportedAt: DateTime.parse(data.$1),
      transactions: (data.$2['transactions'] as List).length,
    );
  }

  /// Replaces everything on this device with the backup, all or nothing.
  Future<void> importJson(String json) async {
    final (_, data) = _parse(json);

    List<Map<String, dynamic>> list(String key) =>
        (data[key] as List).cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      await eraseAll();
      await _db.batch((b) {
        b
          ..insertAll(_db.categories, list('categories').map(Category.fromJson))
          ..insertAll(_db.accounts, list('accounts').map(Account.fromJson))
          ..insertAll(
            _db.recurringRules,
            list('recurringRules').map(RecurringRule.fromJson),
          )
          ..insertAll(
            _db.transactions,
            list('transactions').map(LedgerEntry.fromJson),
          )
          ..insertAll(_db.budgets, list('budgets').map(Budget.fromJson))
          ..insertAll(_db.goals, list('goals').map(Goal.fromJson))
          ..insertAll(
            _db.goalContributions,
            list('goalContributions').map(GoalContribution.fromJson),
          )
          ..insertAll(
            _db.exchangeRates,
            list('exchangeRates').map(StoredRate.fromJson),
          )
          ..insertAll(_db.settings, list('settings').map(Setting.fromJson));
      });
    });
  }

  /// Transactions as CSV for spreadsheets, newest first.
  Future<String> exportCsv() async {
    final rows = await (_db.select(_db.transactions).join([
      innerJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.transactions.accountId),
      ),
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])..orderBy([OrderingTerm.desc(_db.transactions.occurredAt)])).get();

    String cell(Object? value) {
      final text = value?.toString() ?? '';
      return text.contains(RegExp('[",\n]'))
          ? '"${text.replaceAll('"', '""')}"'
          : text;
    }

    final buffer = StringBuffer(
      'date,title,category,account,type,amount,currency,note\n',
    );
    for (final row in rows) {
      final t = row.readTable(_db.transactions);
      final decimals = t.currency == 'JPY' ? 0 : 2;
      final amount = (t.amountMinor / (decimals == 0 ? 1 : 100))
          .toStringAsFixed(decimals);
      buffer.writeln(
        [
          t.occurredAt.toIso8601String(),
          t.title,
          row.readTableOrNull(_db.categories)?.name,
          row.readTable(_db.accounts).name,
          t.kind.name,
          amount,
          t.currency,
          t.note,
        ].map(cell).join(','),
      );
    }
    return buffer.toString();
  }

  /// Deletes every row in every table, children before parents.
  Future<void> eraseAll() => _db.transaction(() async {
    for (final table in <TableInfo<Table, dynamic>>[
      _db.goalContributions,
      _db.goals,
      _db.budgets,
      _db.transactions,
      _db.recurringRules,
      _db.accounts,
      _db.categories,
      _db.exchangeRates,
      _db.settings,
    ]) {
      await _db.delete(table).go();
    }
  });

  (String, Map<String, dynamic>) _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupFormatException('Not a JSON file');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != _app) {
      throw const BackupFormatException('Not a Cent backup');
    }
    if (decoded['version'] != formatVersion) {
      throw const BackupFormatException('Unsupported backup version');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic> || data['transactions'] is! List) {
      throw const BackupFormatException('Backup is incomplete');
    }
    return (decoded['exportedAt'] as String, data);
  }
}
