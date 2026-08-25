import 'package:drift/drift.dart';

import '../../domain/models/cloud_space.dart';
import '../db/app_database.dart';

/// 云空间绑定仓库。
class CloudSpaceRepository {
  CloudSpaceRepository(this._db);

  final AppDatabase _db;

  Stream<List<CloudSpace>> watchAll() {
    return _db.select(_db.cloudSpaces).watch().map(
        (rows) => rows.map(AppDatabase.toCloudSpace).toList());
  }

  Future<List<CloudSpace>> getAll() async {
    final rows = await _db.select(_db.cloudSpaces).get();
    return rows.map(AppDatabase.toCloudSpace).toList();
  }

  Future<CloudSpace?> getByPet(String petId) async {
    final rows = await (_db.select(_db.cloudSpaces)
          ..where((t) => t.petId.equals(petId)))
        .get();
    return rows.isEmpty ? null : AppDatabase.toCloudSpace(rows.first);
  }

  Future<void> upsert(CloudSpace space) async {
    await _db.into(_db.cloudSpaces).insertOnConflictUpdate(
        AppDatabase.toCloudSpacesCompanion(space));
  }

  Future<void> updateSynced(String petId, int version) async {
    await (_db.update(_db.cloudSpaces)..where((t) => t.petId.equals(petId)))
        .write(CloudSpacesCompanion(
      lastVersion: Value(version),
      lastSyncAt: Value(DateTime.now()),
    ));
  }

  Future<void> delete(String petId) async {
    await (_db.delete(_db.cloudSpaces)..where((t) => t.petId.equals(petId)))
        .go();
  }
}
