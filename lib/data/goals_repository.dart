import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/money/currency.dart';
import '../core/money/money.dart';

class GoalProgress {
  const GoalProgress(this.goal, this.savedMinor);

  final Goal goal;
  final int savedMinor;

  Currency get currency => Currency.of(goal.currency);
  Money get saved => Money(savedMinor, currency);
  Money get target => Money(goal.targetMinor, currency);
  Money get remaining => Money(
    (goal.targetMinor - savedMinor).clamp(0, goal.targetMinor),
    currency,
  );
  double get ratio => goal.targetMinor == 0 ? 0 : savedMinor / goal.targetMinor;
  bool get isComplete => savedMinor >= goal.targetMinor;

  /// Monthly amount that reaches the target by its date, counting the
  /// current month. Null without a target date.
  Money? monthlyNeeded(DateTime now) {
    final due = goal.targetDate;
    if (due == null || isComplete) return null;
    final months = (due.year - now.year) * 12 + due.month - now.month + 1;
    return Money(
      (remaining.minor / (months < 1 ? 1 : months)).ceil(),
      currency,
    );
  }
}

class GoalsRepository {
  GoalsRepository(this._db);

  final AppDatabase _db;

  /// Goals with their saved total, unfinished first.
  Stream<List<GoalProgress>> watchAll() {
    final query = _db.customSelect(
      'SELECT g.*, COALESCE(SUM(c.amount_minor), 0) AS saved_minor '
      'FROM goals g LEFT JOIN goal_contributions c ON c.goal_id = g.id '
      'GROUP BY g.id ORDER BY g.completed_at IS NOT NULL, g.created_at',
      readsFrom: {_db.goals, _db.goalContributions},
    );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          GoalProgress(_db.goals.map(row.data), row.read<int>('saved_minor')),
      ],
    );
  }

  Stream<GoalProgress?> watchOne(int id) =>
      watchAll().map((all) => all.where((g) => g.goal.id == id).firstOrNull);

  Stream<List<GoalContribution>> watchContributions(int goalId) =>
      (_db.select(_db.goalContributions)
            ..where((c) => c.goalId.equals(goalId))
            ..orderBy([(c) => OrderingTerm.desc(c.occurredAt)]))
          .watch();

  Future<int> create({
    required String name,
    required String icon,
    required String tint,
    required Money target,
    DateTime? targetDate,
    int? sourceAccountId,
  }) => _db
      .into(_db.goals)
      .insert(
        GoalsCompanion.insert(
          name: name,
          icon: icon,
          tint: tint,
          targetMinor: target.minor,
          currency: target.currency.code,
          targetDate: Value(targetDate),
          sourceAccountId: Value(sourceAccountId),
        ),
      );

  Future<void> update(
    int id, {
    required String name,
    required String icon,
    required String tint,
    required int targetMinor,
    DateTime? targetDate,
  }) => (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
    GoalsCompanion(
      name: Value(name),
      icon: Value(icon),
      tint: Value(tint),
      targetMinor: Value(targetMinor),
      targetDate: Value(targetDate),
    ),
  );

  Future<void> delete(int id) =>
      (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();

  /// Records money set aside and marks the goal complete once reached.
  Future<void> contribute(
    int goalId,
    Money amount, {
    required DateTime at,
    int? fromAccountId,
    String? note,
  }) => _db.transaction(() async {
    await _db
        .into(_db.goalContributions)
        .insert(
          GoalContributionsCompanion.insert(
            goalId: goalId,
            amountMinor: amount.minor,
            fromAccountId: Value(fromAccountId),
            note: Value(note),
            occurredAt: at,
          ),
        );
    final progress = await watchOne(goalId).first;
    if (progress != null && progress.isComplete) {
      await (_db.update(_db.goals)
            ..where((g) => g.id.equals(goalId) & g.completedAt.isNull()))
          .write(GoalsCompanion(completedAt: Value(at)));
    }
  });
}
