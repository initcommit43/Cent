import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchAll({CategoryKind? kind}) {
    final query = _db.select(_db.categories)
      ..where((c) => c.archived.equals(false))
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    if (kind != null) query.where((c) => c.kind.equalsValue(kind));
    return query.watch();
  }

  Future<int> create({
    required String name,
    required String icon,
    required String tint,
    required CategoryKind kind,
  }) async {
    final max = _db.categories.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.categories,
    )..addColumns([max])).getSingle();
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            tint: tint,
            kind: kind,
            sortOrder: Value((row.read(max) ?? -1) + 1),
          ),
        );
  }

  Future<void> edit(
    int id, {
    required String name,
    required String icon,
    required String tint,
  }) => (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
    CategoriesCompanion(
      name: Value(name),
      icon: Value(icon),
      tint: Value(tint),
    ),
  );

  /// Persists a new order after a drag in the categories list.
  Future<void> reorder(List<int> orderedIds) => _db.batch((batch) {
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        _db.categories,
        CategoriesCompanion(sortOrder: Value(i)),
        where: (c) => c.id.equals(orderedIds[i]),
      );
    }
  });

  /// Archives the category and moves its transactions to [fallbackId], so
  /// history stays complete.
  Future<void> archive(int id, {required int fallbackId}) =>
      _db.transaction(() async {
        await (_db.update(_db.transactions)
              ..where((t) => t.categoryId.equals(id)))
            .write(TransactionsCompanion(categoryId: Value(fallbackId)));
        await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
          const CategoriesCompanion(archived: Value(true)),
        );
      });
}
