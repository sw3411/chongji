import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/expense.dart';
import '../db/app_database.dart';

/// 消费仓库。
class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 全部消费（petId 为空的“全体消费”也包含；不含墓碑）。
  Stream<List<Expense>> watchAll() {
    return (_db.select(_db.expenses)..where((t) => t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(AppDatabase.toExpense).toList());
  }

  Future<List<Expense>> getAll() async {
    final rows = await (_db.select(_db.expenses)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return rows.map(AppDatabase.toExpense).toList();
  }

  Future<Expense?> getById(String id) async {
    final rows = await (_db.select(_db.expenses)
          ..where((t) => t.id.equals(id)))
        .get();
    return rows.isEmpty ? null : AppDatabase.toExpense(rows.first);
  }

  Future<void> upsert(Expense expense) async {
    final e = expense.id.isEmpty
        ? Expense(
            id: _uuid.v4(),
            petId: expense.petId,
            category: expense.category,
            title: expense.title,
            amount: expense.amount,
            date: expense.date,
            notes: expense.notes,
            imagePaths: expense.imagePaths,
            relatedRecordId: expense.relatedRecordId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : expense.copyWith(updatedAt: DateTime.now());
    await _db.into(_db.expenses).insertOnConflictUpdate(
        AppDatabase.toExpensesCompanion(e));
  }

  /// 软删除（写墓碑，云同步用）。
  Future<void> delete(String id) async {
    await (_db.update(_db.expenses)..where((t) => t.id.equals(id)))
        .write(ExpensesCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 物理清理超过 [days] 的墓碑（启动时调用）。
  Future<void> purge(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await (_db.delete(_db.expenses)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
