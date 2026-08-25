import 'package:drift/drift.dart';

import '../../domain/models/pet.dart';
import '../db/app_database.dart';

/// 宠物仓库。软删除进回收站场景由 UI 层决定，这里提供原语。
class PetRepository {
  PetRepository(this._db);

  final AppDatabase _db;

  /// 全部宠物（含软删除），过滤在内存层做。
  Stream<List<Pet>> watchAll() {
    return _db.select(_db.pets).watch().map(
        (rows) => rows.map(AppDatabase.toPet).toList());
  }

  Future<List<Pet>> getAll() async {
    final rows = await _db.select(_db.pets).get();
    return rows.map(AppDatabase.toPet).toList();
  }

  Future<Pet?> getById(String id) async {
    final rows = await (_db.select(_db.pets)
          ..where((t) => t.id.equals(id)))
        .get();
    return rows.isEmpty ? null : AppDatabase.toPet(rows.first);
  }

  Future<void> upsert(Pet pet) async {
    await _db.into(_db.pets).insertOnConflictUpdate(
        AppDatabase.toPetsCompanion(pet));
  }

  Future<void> softDelete(String id) async {
    await (_db.update(_db.pets)..where((t) => t.id.equals(id))).write(
        PetsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now())));
  }

  Future<void> restore(String id) async {
    await (_db.update(_db.pets)..where((t) => t.id.equals(id))).write(
        const PetsCompanion(deletedAt: Value(null)));
  }

  /// 硬删除：级联清理全部关联数据（事务保证不留半完成状态）。
  Future<void> hardDelete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.healthRecords)
            ..where((t) => t.petId.equals(id)))
          .go();
      await (_db.delete(_db.moments)..where((t) => t.petId.equals(id))).go();
      await (_db.update(_db.expenses)..where((t) => t.petId.equals(id)))
          .write(ExpensesCompanion(petId: const Value(null)));
      await (_db.delete(_db.dietProfiles)..where((t) => t.petId.equals(id)))
          .go();
      await (_db.delete(_db.mealPlans)..where((t) => t.petId.equals(id))).go();
      await (_db.delete(_db.pets)..where((t) => t.id.equals(id))).go();
    });
  }
}
