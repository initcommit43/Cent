import '../../core/database/app_database.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/rates_repository.dart';
import '../../data/transactions_repository.dart';

/// Totals across entries in mixed currencies, expressed in the base
/// currency. Transfers are excluded: they move money, they don't spend it.
class EntryTotals {
  EntryTotals(Iterable<EntryView> entries, CurrencyConverter converter)
    : this._(entries, converter, converter.base);

  EntryTotals._(
    Iterable<EntryView> entries,
    CurrencyConverter converter,
    Currency base,
  ) : spent = _sum(entries, converter, base, TransactionKind.expense),
      income = _sum(entries, converter, base, TransactionKind.income);

  final Money spent;
  final Money income;

  Money get net => income - spent;

  static Money _sum(
    Iterable<EntryView> entries,
    CurrencyConverter converter,
    Currency base,
    TransactionKind kind,
  ) {
    var total = Money.zero(base);
    for (final e in entries.where((e) => e.entry.kind == kind)) {
      total += converter.convert(e.amount, base).abs();
    }
    return total;
  }
}

/// Entries grouped by calendar day, newest day first.
List<(DateTime day, List<EntryView> entries)> groupByDay(
  List<EntryView> entries,
) {
  final groups = <(DateTime, List<EntryView>)>[];
  for (final e in entries) {
    final at = e.entry.occurredAt;
    final day = DateTime(at.year, at.month, at.day);
    if (groups.isEmpty || groups.last.$1 != day) {
      groups.add((day, [e]));
    } else {
      groups.last.$2.add(e);
    }
  }
  return groups;
}
