import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/moment.dart';
import '../db/app_database.dart';

/// 时刻仓库。
class MomentRepository {
  MomentRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Moment>> watchByPet(String petId) {
    final query = _db.select(_db.moments)
      ..where((t) => t.petId.equals(petId) & t.deletedAt.isNull());
    return query.watch().map((rows) => rows.map(AppDatabase.toMoment).toList());
  }

  /// 全部宠物的时刻（时间线页）。
  Stream<List<Moment>> watchAll() {
    return (_db.select(_db.moments)..where((t) => t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(AppDatabase.toMoment).toList());
  }

  /// 全部时刻（未删除；备份/引用统计用）。
  Future<List<Moment>> getAll() async {
    final rows = await (_db.select(_db.moments)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return rows.map(AppDatabase.toMoment).toList();
  }

  Future<Moment?> getById(String id) async {
    final rows = await (_db.select(_db.moments)..where((t) => t.id.equals(id)))
        .get();
    return rows.isEmpty ? null : AppDatabase.toMoment(rows.first);
  }

  Future<void> upsert(Moment moment) async {
    final m = moment.id.isEmpty
        ? Moment(
            id: _uuid.v4(),
            petId: moment.petId,
            type: moment.type,
            date: moment.date,
            title: moment.title,
            notes: moment.notes,
            location: moment.location,
            imagePaths: moment.imagePaths,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : moment.copyWith(updatedAt: DateTime.now());
    await _db.into(_db.moments).insertOnConflictUpdate(
        AppDatabase.toMomentsCompanion(m));
  }

  /// 软删除（写墓碑，云同步用）。
  Future<void> delete(String id) async {
    await (_db.update(_db.moments)..where((t) => t.id.equals(id)))
        .write(MomentsCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 物理清理超过 [days] 的墓碑（启动时调用）。
  Future<void> purge(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await (_db.delete(_db.moments)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
