import '../core/database/app_database.dart';

/// The occurrence after [from] for a rule anchored on [anchor].
///
/// Monthly and yearly rules keep the anchor's day and clamp it to short
/// months, so a rule on the 31st falls on Feb 28 (or 29) and returns to the
/// 31st afterwards instead of drifting.
DateTime nextOccurrence({
  required DateTime anchor,
  required DateTime from,
  required Frequency frequency,
  int interval = 1,
}) {
  switch (frequency) {
    case Frequency.weekly:
      final step = Duration(days: 7 * interval);
      var next = anchor;
      while (!next.isAfter(from)) {
        next = next.add(step);
      }
      return next;
    case Frequency.monthly:
    case Frequency.yearly:
      final months = frequency == Frequency.monthly ? interval : 12 * interval;
      var n = 0;
      DateTime next;
      do {
        n += months;
        next = _addMonthsClamped(anchor, n);
      } while (!next.isAfter(from));
      return next;
  }
}

DateTime _addMonthsClamped(DateTime anchor, int months) {
  final target = DateTime(anchor.year, anchor.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    anchor.day > lastDay ? lastDay : anchor.day,
    anchor.hour,
    anchor.minute,
  );
}

/// Average monthly cost of a rule, for "€358 a month in fixed costs".
int monthlyEquivalentMinor(
  int amountMinor,
  Frequency frequency,
  int interval,
) => switch (frequency) {
  Frequency.weekly => (amountMinor * 52 / 12 / interval).round(),
  Frequency.monthly => (amountMinor / interval).round(),
  Frequency.yearly => (amountMinor / 12 / interval).round(),
};
