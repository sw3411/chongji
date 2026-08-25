import 'package:chongji/core/cloud/space_sync.dart';
import 'package:chongji/data/db/app_database.dart';
import 'package:chongji/data/repositories/health_record_repository.dart';
import 'package:chongji/domain/models/enums.dart';
import 'package:chongji/domain/models/health_record.dart';
import 'package:chongji/domain/models/pet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Pet newPet() => Pet(
      id: 'pet-1',
      name: '豆豆',
      species: PetSpecies.dog,
      breed: '柴犬',
      birthday: DateTime(2024, 5, 1),
      neutered: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Pet petJsonToPetUnused(Map<String, dynamic> json) => Pet.fromJson(json);

HealthRecord rec(String id, DateTime date, {double? value, DateTime? deleted}) =>
    HealthRecord(
      id: id,
      petId: 'pet-1',
      type: HealthRecordType.weight,
      date: date,
      value: value,
      deletedAt: deleted,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collectSnapshotRaw 图片路径归一', () {
    test('绝对路径 → 文件名并汇总', () {
      final snap = collectSnapshotRaw(
        {
          ...newPet().toJson(),
          'avatarPath': '/var/mobile/xxx/images/avatar.jpg',
        },
        [
          HealthRecord(
            id: 'r1',
            petId: 'pet-1',
            type: HealthRecordType.vetVisit,
            date: DateTime(2026, 8, 1),
            imagePaths: const ['/a/b/img1.jpg', '/c/d/img2.jpg'],
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ).toJson(),
        ],
        [],
        [],
      );
      expect(snap.pet['avatarPath'], 'avatar.jpg');
      expect(snap.records.first['imagePaths'], ['img1.jpg', 'img2.jpg']);
      expect(snap.imageNames,
          containsAll(['avatar.jpg', 'img1.jpg', 'img2.jpg']));
    });
  });

  group('applySnapshot LWW 与墓碑', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    SpaceSnapshot snapOf(Pet pet, List<HealthRecord> records) =>
        SpaceSnapshot(
          pet: pet.toJson(),
          records: [for (final r in records) r.toJson()],
          moments: [],
          expenses: [],
          imageNames: [],
        );

    test('新宠物与记录插入', () async {
      final pet = newPet();
      final r = rec('r1', DateTime(2026, 8, 1), value: 5.0);
      final petId =
          await applySnapshotIn(db, snapOf(pet, [r]), '/tmp/images');
      expect(petId, pet.id);
      final loaded = await HealthRecordRepository(db).getByPet(pet.id);
      expect(loaded.length, 1);
      expect(loaded.first.value, 5.0);
    });

    test('远端更新则覆盖（LWW），本地更新则保留', () async {
      final pet = newPet();
      final old = rec('r1', DateTime(2026, 8, 1), value: 5.0)
          .copyWith(updatedAt: DateTime(2026, 8, 1));
      await applySnapshotIn(db, snapOf(pet, [old]), '/tmp/images');

      // 远端更新（updatedAt 更新）→ 覆盖。
      final newerRemote = rec('r1', DateTime(2026, 8, 2), value: 5.4)
          .copyWith(updatedAt: DateTime(2026, 8, 10));
      await applySnapshotIn(db, snapOf(pet, [newerRemote]), '/tmp/images');
      var loaded = await HealthRecordRepository(db).getByPet(pet.id);
      expect(loaded.first.value, 5.4);

      // 本地更新（远端条目 updatedAt 更旧）→ 保留本地。
      final staleRemote = rec('r1', DateTime(2026, 8, 2), value: 9.9)
          .copyWith(updatedAt: DateTime(2026, 8, 5));
      await applySnapshotIn(db, snapOf(pet, [staleRemote]), '/tmp/images');
      loaded = await HealthRecordRepository(db).getByPet(pet.id);
      expect(loaded.first.value, 5.4);
    });

    test('墓碑同步为软删除，列表不可见、库内保留', () async {
      final pet = newPet();
      final alive = rec('r1', DateTime(2026, 8, 1), value: 5.0);
      await applySnapshotIn(db, snapOf(pet, [alive]), '/tmp/images');

      final tombstoned = HealthRecord(
        id: 'r1',
        petId: pet.id,
        type: HealthRecordType.weight,
        date: DateTime(2026, 8, 1),
        value: 5.0,
        deletedAt: DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 20),
      );
      await applySnapshotIn(db, snapOf(pet, [tombstoned]), '/tmp/images');

      final visible = await HealthRecordRepository(db).getByPet(pet.id);
      expect(visible, isEmpty); // 常规读取被过滤
      // 原始行仍在（墓碑保留，供再同步）。
      final raw = await (db.select(db.healthRecords)
            ..where((t) => t.id.equals('r1')))
          .get();
      expect(raw.length, 1);
      expect(raw.first.deletedAt, isNotNull);
    });
  });

  group('hasLocalChanges 脏检查', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    test('水位线后无修改 → false；有新增/修改/删除 → true', () async {
      final watermark = DateTime(2026, 8, 25, 12, 0);
      final pet = newPet();
      final repo = HealthRecordRepository(db);

      // 早于水位线的记录 + 档案（直接写库，保留指定时间戳）。
      await db.into(db.pets).insertOnConflictUpdate(
          AppDatabase.toPetsCompanion(pet));
      await db.into(db.healthRecords).insertOnConflictUpdate(
          AppDatabase.toHealthRecordsCompanion(
              rec('r1', DateTime(2026, 8, 1), value: 5.0)));
      expect(await hasLocalChanges(db, pet.id, watermark), isFalse);

      // 修改（updatedAt 晚于水位线）。
      await db.into(db.healthRecords).insertOnConflictUpdate(
          AppDatabase.toHealthRecordsCompanion(HealthRecord(
            id: 'r1',
            petId: pet.id,
            type: HealthRecordType.weight,
            date: DateTime(2026, 8, 1),
            value: 5.4,
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 25, 13, 0),
          )));
      expect(await hasLocalChanges(db, pet.id, watermark), isTrue);

      // 档案本身的修改也算。
      await db.into(db.pets).insertOnConflictUpdate(
          AppDatabase.toPetsCompanion(pet.copyWith(
              name: '豆豆2', updatedAt: DateTime(2026, 8, 26))));
      expect(await hasLocalChanges(db, pet.id, watermark), isTrue);

      // 墓碑（删除）晚于水位线也算修改。
      expect(
        await (() async {
          await repo.delete('r1'); // 软删除 = updatedAt = now（晚于水位线）
          return hasLocalChanges(db, pet.id, watermark);
        })(),
        isTrue,
      );
    });

    test('不存在的宠物恒为 false', () async {
      expect(await hasLocalChanges(db, 'ghost', DateTime(2000)), isFalse);
    });
  });
}
