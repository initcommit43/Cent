import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

int daysLeftInMonth(DateTime now) =>
    DateTime(now.year, now.month + 1, 0).day - now.day + 1;

/// "Today", "Yesterday" or "Thu, Oct 2".
String dayLabel(BuildContext context, DateTime day, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final diff = dateOnly(now).difference(dateOnly(day)).inDays;
  if (diff == 0) return l10n.today;
  if (diff == 1) return l10n.yesterday;
  final locale = Localizations.localeOf(context).toString();
  final pattern = day.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y';
  return DateFormat(pattern, locale).format(day);
}

String timeLabel(BuildContext context, DateTime at) =>
    DateFormat.Hm(Localizations.localeOf(context).toString()).format(at);

String monthName(BuildContext context, DateTime month) =>
    DateFormat.MMMM(Localizations.localeOf(context).toString()).format(month);

String monthYear(BuildContext context, DateTime month) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(month);

String fullDate(BuildContext context, DateTime at) => DateFormat(
  'EEE, MMM d, y · HH:mm',
  Localizations.localeOf(context).toString(),
).format(at);
