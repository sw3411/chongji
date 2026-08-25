import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/health_record.dart';
import '../db/app_database.dart';

/// 健康记录仓库。
class HealthRecordRepository {
  HealthRecordRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<HealthRecord>> watchByPet(String petId) {
    final query = _db.select(_db.healthRecords)
      ..where((t) => t.petId.equals(petId) & t.deletedAt.isNull());
    return query.watch().map(
        (rows) => rows.map(AppDatabase.toHealthRecord).toList());
  }

  Future<List<HealthRecord>> getByPet(String petId) async {
    final query = _db.select(_db.healthRecords)
      ..where((t) => t.petId.equals(petId) & t.deletedAt.isNull());
    final rows = await query.get();
    return rows.map(AppDatabase.toHealthRecord).toList();
  }

  Future<HealthRecord?> getById(String id) async {
    final rows = await (_db.select(_db.healthRecords)
          ..where((t) => t.id.equals(id)))
        .get();
    return rows.isEmpty ? null : AppDatabase.toHealthRecord(rows.first);
  }

  /// 新建（生成 uuid）或更新。
  Future<void> upsert(HealthRecord record) async {
    final r = record.id.isEmpty
        ? HealthRecord(
            id: _uuid.v4(),
            petId: record.petId,
            type: record.type,
            date: record.date,
            value: record.value,
            textValue: record.textValue,
            diagnosis: record.diagnosis,
            cycleDays: record.cycleDays,
            notes: record.notes,
            imagePaths: record.imagePaths,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : record.copyWith(updatedAt: DateTime.now());
    await _db.into(_db.healthRecords).insertOnConflictUpdate(
        AppDatabase.toHealthRecordsCompanion(r));
  }

  /// 软删除（写墓碑，云同步用）；物理清理见 [purge]。
  Future<void> delete(String id) async {
    await (_db.update(_db.healthRecords)..where((t) => t.id.equals(id)))
        .write(HealthRecordsCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 物理清理超过 [days] 的墓碑（启动时调用）。
  Future<void> purge(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await (_db.delete(_db.healthRecords)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
