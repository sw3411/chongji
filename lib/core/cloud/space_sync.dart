import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../../app/image_store.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/cloud_space_repository.dart';
import '../../domain/models/cloud_space.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import 'space_crypto.dart';
import 'tos_client.dart';

/// 一键同步结果：无变化 / 仅拉取 / 已推送。
enum SyncOutcome { upToDate, pulled, pushed }

/// 空间成员（角色由客户端遵循 + manifest 审计兜底）。
class SpaceMember {
  SpaceMember({required this.name, required this.role, this.addedAt});

  final String name;

  /// manage / edit / view
  final String role;
  final DateTime? addedAt;

  factory SpaceMember.fromJson(Map<String, dynamic> json) => SpaceMember(
        name: json['name'] as String,
        role: json['role'] as String? ?? 'view',
        addedAt: json['addedAt'] == null
            ? null
            : DateTime.parse(json['addedAt'] as String),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'role': role, 'addedAt': addedAt?.toIso8601String()};

  String get roleLabel => switch (role) {
        'manage' => '管理',
        'edit' => '编辑',
        _ => '查看',
      };
}

/// 空间元数据（manifest.enc，用 dataKey 加密）。
class SpaceManifest {
  SpaceManifest({
    required this.code,
    required this.petId,
    required this.petName,
    required this.version,
    required this.updatedAt,
    required this.updatedBy,
    required this.members,
  });

  final String code;
  final String petId;
  final String petName;
  final int version;
  final DateTime updatedAt;
  final String updatedBy;
  final List<SpaceMember> members;

  factory SpaceManifest.fromJson(Map<String, dynamic> json) => SpaceManifest(
        code: json['code'] as String,
        petId: json['petId'] as String,
        petName: json['petName'] as String? ?? '',
        version: json['version'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        updatedBy: json['updatedBy'] as String? ?? '',
        members: (json['members'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SpaceMember.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'petId': petId,
        'petName': petName,
        'version': version,
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': updatedBy,
        'members': members.map((m) => m.toJson()).toList(),
      };

  SpaceManifest copyWith({
    int? version,
    DateTime? updatedAt,
    String? updatedBy,
    List<SpaceMember>? members,
  }) =>
      SpaceManifest(
        code: code,
        petId: petId,
        petName: petName,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy ?? this.updatedBy,
        members: members ?? this.members,
      );
}

/// 空间数据快照（data.enc，用 dataKey 加密，复用领域模型序列化）。
/// 图片路径统一归一为文件名，落到各设备本地图片目录。
class SpaceSnapshot {
  SpaceSnapshot({
    required this.pet,
    required this.records,
    required this.moments,
    required this.expenses,
    required this.imageNames,
  });

  final Map<String, dynamic> pet;
  final List<Map<String, dynamic>> records;
  final List<Map<String, dynamic>> moments;

  /// 仅该宠物的消费（「全体」消费不参与共享）。
  final List<Map<String, dynamic>> expenses;
  final List<String> imageNames;

  factory SpaceSnapshot.fromJson(Map<String, dynamic> json) => SpaceSnapshot(
        pet: json['pet'] as Map<String, dynamic>? ?? {},
        records: (json['records'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        moments: (json['moments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        expenses: (json['expenses'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        imageNames: (json['images'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'pet': pet, 'records': records, 'moments': moments, 'expenses': expenses, 'images': imageNames};
}

/// 云空间对象布局：
/// - keyring.json  明文（只含被密码/恢复码包裹后的 dataKey，本身是密文安全）
/// - manifest.enc  空间元数据（dataKey 加密）
/// - data.enc      宠物数据快照（dataKey 加密）
/// - img/{name}.enc 图片（dataKey 加密，uuid 文件名幂等）
class SpaceSync {
  SpaceSync(this._db, this._spaces);

  final AppDatabase _db;
  final CloudSpaceRepository _spaces;

  static const _secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static String _keyName(String code) => 'chongji.space.$code.dataKey';

  // ---------- dataKey 管理（本机钥匙串） ----------

  static Future<void> saveDataKey(String code, SecretKey key) async =>
      _secure.write(
          key: _keyName(code), value: await SpaceCrypto.encodeKey(key));

  static Future<SecretKey?> loadDataKey(String code) async {
    final v = await _secure.read(key: _keyName(code));
    if (v == null || v.isEmpty) return null;
    return SpaceCrypto.decodeKey(v);
  }

  static Future<void> deleteDataKey(String code) =>
      _secure.delete(key: _keyName(code));

  TosClient _clientOf(CloudSpace s) => TosClient(
        endpoint: s.endpoint,
        bucket: s.bucket,
        accessKey: s.accessKey,
        secretKey: s.secretKey,
      );

  static String keyringObjectKey(String code) => 'spaces/$code/keyring.json';
  static String manifestObjectKey(String code) => 'spaces/$code/manifest.enc';
  static String dataObjectKey(String code) => 'spaces/$code/data.enc';
  static String imageObjectKey(String code, String name) =>
      'spaces/$code/img/$name.enc';

  // ---------- 创建 ----------

  /// 创建空间（管理角色）。返回恢复码（仅此一次展示，务必保存）。
  Future<String> createSpace(
    CloudSpace space,
    String passphrase,
    Pet pet,
  ) async {
    if (await _spaces.getByPet(space.petId) != null) {
      throw TosException('这只宠物已开启云空间');
    }
    if (!space.hasCredentials) {
      throw TosException('创建空间需要填写 TOS 写入密钥（AK/SK）');
    }
    final code = SpaceCrypto.generateCode();
    final dataKey = await SpaceCrypto.randomDataKey();
    final recovery = SpaceCrypto.generateRecoveryCode();
    final manifest = SpaceManifest(
      code: code,
      petId: pet.id,
      petName: pet.name,
      version: 1,
      updatedAt: DateTime.now(),
      updatedBy: space.memberName,
      members: [
        SpaceMember(name: space.memberName, role: 'manage', addedAt: DateTime.now()),
      ],
    );
    final client = _clientOf(space);
    await _uploadKeyring(client, code, dataKey, passphrase, recovery);
    await _pushSnapshot(client, code, dataKey, manifest,
        await _collect(space.petId));
    await saveDataKey(code, dataKey);
    await _spaces.upsert(CloudSpace(
      petId: space.petId,
      code: code,
      endpoint: space.endpoint,
      bucket: space.bucket,
      role: 'manage',
      memberName: space.memberName,
      accessKey: space.accessKey,
      secretKey: space.secretKey,
      lastVersion: manifest.version,
      lastSyncAt: DateTime.now(),
      createdAt: DateTime.now(),
    ));
    return recovery;
  }

  // ---------- 加入 ----------

  /// 加入空间：暗号+密码 → 解出 dataKey → 拉取快照落到本机。
  Future<String> joinSpace({
    required String endpoint,
    required String bucket,
    required String code,
    required String passphrase,
    required String memberName,
    required String role,
    String accessKey = '',
    String secretKey = '',
  }) async {
    final client = TosClient(
        endpoint: endpoint,
        bucket: bucket,
        accessKey: accessKey,
        secretKey: secretKey);
    final dataKey = await unlockKeyring(client, code, passphrase);
    final manifest =
        await fetchManifest(client, code, dataKey);
    final snapBytes = await client.publicGet(dataObjectKey(code));
    if (snapBytes == null) throw TosException('空间数据不存在');
    final snapshot = SpaceSnapshot.fromJson(
        await SpaceCrypto.decryptJson(dataKey, snapBytes));
    final petId = await applySnapshot(_db, snapshot);
    await saveDataKey(code, dataKey);
    await _downloadImages(client, code, dataKey, snapshot);
    await _spaces.upsert(CloudSpace(
      petId: petId,
      code: code,
      endpoint: endpoint,
      bucket: bucket,
      role: role,
      memberName: memberName,
      accessKey: accessKey,
      secretKey: secretKey,
      lastVersion: manifest.version,
      lastSyncAt: DateTime.now(),
      createdAt: DateTime.now(),
    ));
    return petId;
  }

  // ---------- keyring / manifest ----------

  static Future<void> _uploadKeyring(TosClient client, String code,
      SecretKey dataKey, String passphrase, String recovery) async {
    final body = jsonEncode({
      'pass': await SpaceCrypto.wrapKey(dataKey, passphrase),
      'recovery': await SpaceCrypto.wrapKey(dataKey, recovery),
    });
    await client.put(
        keyringObjectKey(code), Uint8List.fromList(utf8.encode(body)));
  }

  /// 用密码（或恢复码）从明文 keyring 解出 dataKey。
  static Future<SecretKey> unlockKeyring(
      TosClient client, String code, String passphrase) async {
    final bytes = await client.publicGet(keyringObjectKey(code));
    if (bytes == null) throw TosException('空间不存在（暗号有误或已被删除）');
    Map<String, dynamic> keyring;
    try {
      keyring = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw TosException('空间数据格式不正确');
    }
    // 先按密码试，再按恢复码试。
    try {
      return await SpaceCrypto.unwrapKey(
          keyring['pass'] as Map<String, dynamic>, passphrase);
    } on SpaceAuthException {
      return await SpaceCrypto.unwrapKey(
          keyring['recovery'] as Map<String, dynamic>, passphrase);
    }
  }

  /// 拉取并解密 manifest。
  static Future<SpaceManifest> fetchManifest(
      TosClient client, String code, SecretKey dataKey) async {
    final bytes = await client.publicGet(manifestObjectKey(code));
    if (bytes == null) throw TosException('空间不存在或已被删除');
    return SpaceManifest.fromJson(
        await SpaceCrypto.decryptJson(dataKey, bytes));
  }

  // ---------- 同步 ----------

  /// 拉取并合并（所有角色）。
  Future<void> pull(CloudSpace space, {bool downloadImages = true}) async {
    final dataKey = await loadDataKey(space.code);
    if (dataKey == null) throw SpaceAuthException('本机空间密钥丢失，请重新加入空间');
    final client = _clientOf(space);
    final manifest = await fetchManifest(client, space.code, dataKey);
    if (manifest.version <= space.lastVersion) return; // 已是最新
    final snapBytes = await client.publicGet(dataObjectKey(space.code));
    if (snapBytes == null) throw TosException('空间数据不存在');
    final snapshot =
        SpaceSnapshot.fromJson(await SpaceCrypto.decryptJson(dataKey, snapBytes));
    await applySnapshot(_db, snapshot);
    if (downloadImages) {
      await _downloadImages(client, space.code, dataKey, snapshot);
    }
    // 成员角色以 manifest 为准。
    var role = space.role;
    for (final m in manifest.members) {
      if (m.name == space.memberName) role = m.role;
    }
    await _spaces.upsert(space.copyWith(role: role));
    await _spaces.updateSynced(space.petId, manifest.version);
  }

  /// 推送（edit/manage）：先拉合并，再全量上传新版本。
  Future<void> push(CloudSpace space) async {
    if (!space.canWrite) throw TosException('查看权限不能推送');
    if (!space.hasCredentials) throw TosException('未配置写入密钥（AK/SK）');
    final dataKey = await loadDataKey(space.code);
    if (dataKey == null) throw SpaceAuthException('本机空间密钥丢失，请重新加入空间');
    final client = _clientOf(space);
    final manifest = await fetchManifest(client, space.code, dataKey);
    if (manifest.version > space.lastVersion) {
      await pull(space);
    }
    final newManifest = manifest.copyWith(
      version: manifest.version + 1,
      updatedAt: DateTime.now(),
      updatedBy: space.memberName,
    );
    await _pushSnapshot(client, space.code, dataKey, newManifest,
        await _collect(space.petId));
    await _spaces.updateSynced(space.petId, newManifest.version);
  }

  /// 一键同步：先拉取；仅当本地有修改且可写时才推送。
  /// 「有修改即同步，无修改不同步」的核心入口。
  Future<SyncOutcome> sync(CloudSpace space) async {
    var pulled = false;
    final dataKeyBefore = await loadDataKey(space.code);
    if (dataKeyBefore != null) {
      final client = _clientOf(space);
      final manifest =
          await fetchManifest(client, space.code, dataKeyBefore);
      if (manifest.version > space.lastVersion) {
        await pull(space);
        pulled = true;
      }
    }
    // 拉取后重新读绑定（pull 可能更新了角色/版本）。
    final latest = await _spaces.getByPet(space.petId) ?? space;
    if (latest.canWrite &&
        latest.hasCredentials &&
        await hasLocalChanges(_db, latest.petId,
            latest.lastSyncAt ?? DateTime(2000))) {
      await push(latest);
      return SyncOutcome.pushed;
    }
    return pulled ? SyncOutcome.pulled : SyncOutcome.upToDate;
  }

  /// 管理员改密码：重新包裹 dataKey（数据不用重加密）。返回新恢复码。
  Future<String> changePassphrase(
      CloudSpace space, String newPassphrase) async {
    if (!space.canManage) throw TosException('只有管理员可以改密码');
    final dataKey = await loadDataKey(space.code);
    if (dataKey == null) throw SpaceAuthException('本机空间密钥丢失');
    final client = _clientOf(space);
    final manifest = await fetchManifest(client, space.code, dataKey);
    final recovery = SpaceCrypto.generateRecoveryCode();
    await _uploadKeyring(client, space.code, dataKey, newPassphrase, recovery);
    final newManifest = manifest.copyWith(
      version: manifest.version + 1,
      updatedAt: DateTime.now(),
      updatedBy: space.memberName,
    );
    await client.put(
      manifestObjectKey(space.code),
      await SpaceCrypto.encryptJson(dataKey, newManifest.toJson()),
    );
    await _spaces.updateSynced(space.petId, newManifest.version);
    return recovery;
  }

  /// 管理员编辑成员。
  Future<void> updateMembers(
      CloudSpace space, List<SpaceMember> members) async {
    if (!space.canManage) throw TosException('只有管理员可以管理成员');
    final dataKey = await loadDataKey(space.code);
    if (dataKey == null) throw SpaceAuthException('本机空间密钥丢失');
    final client = _clientOf(space);
    final manifest = await fetchManifest(client, space.code, dataKey);
    final newManifest = manifest.copyWith(
      version: manifest.version + 1,
      updatedAt: DateTime.now(),
      updatedBy: space.memberName,
      members: members,
    );
    await client.put(
      manifestObjectKey(space.code),
      await SpaceCrypto.encryptJson(dataKey, newManifest.toJson()),
    );
    await _spaces.updateSynced(space.petId, newManifest.version);
  }

  /// 退出空间（解绑本机 + 删除本机密钥；云端数据不受影响）。
  Future<void> leaveSpace(CloudSpace space) async {
    await _spaces.delete(space.petId);
    await deleteDataKey(space.code);
  }

  // ---------- 内部 ----------

  /// 兼容旧调用名的私有别名（data.enc 的对象 key）。
  Future<void> _pushSnapshot(
    TosClient client,
    String code,
    SecretKey dataKey,
    SpaceManifest manifest,
    SpaceSnapshot snapshot,
  ) async {
    final dir = await ImageStore.imageDir();
    for (final name in snapshot.imageNames) {
      final local = File(p.join(dir.path, name));
      if (!await local.exists()) continue;
      final key = imageObjectKey(code, name);
      if (await client.exists(key)) continue;
      await client.put(
          key, await SpaceCrypto.encryptBytes(dataKey, await local.readAsBytes()));
    }
    // 顺序：数据先到，manifest 版本最后推进（读端以 manifest.version 为准）。
    await client.put(dataObjectKey(code),
        await SpaceCrypto.encryptJson(dataKey, snapshot.toJson()));
    await client.put(manifestObjectKey(code),
        await SpaceCrypto.encryptJson(dataKey, manifest.toJson()));
  }

  Future<SpaceSnapshot> _collect(String petId) async =>
      collectSnapshot(_db, petId);

  Future<void> _downloadImages(
      TosClient client, String code, SecretKey dataKey, SpaceSnapshot snapshot) async {
    final dir = await ImageStore.imageDir();
    for (final name in snapshot.imageNames) {
      final target = File(p.join(dir.path, name));
      if (await target.exists()) continue;
      final bytes = await client.publicGet(imageObjectKey(code, name));
      if (bytes == null) continue;
      try {
        await target
            .writeAsBytes(await SpaceCrypto.decryptBytes(dataKey, bytes));
      } catch (_) {}
    }
  }
}

// ---------- 纯函数部分（可单测） ----------

/// 本地是否有该宠物的修改（updatedAt 晚于水位线 [since]，含墓碑与档案本身）。
/// 「全体」消费不属于任何空间，不参与判断。
Future<bool> hasLocalChanges(
    AppDatabase db, String petId, DateTime since) async {
  final petRow = await (db.select(db.pets)..where((t) => t.id.equals(petId)))
      .get();
  if (petRow.isEmpty) return false;
  if (petRow.first.updatedAt.isAfter(since)) return true;

  final records = await (db.select(db.healthRecords)
        ..where((t) => t.petId.equals(petId)))
      .get();
  for (final r in records) {
    if (r.updatedAt.isAfter(since)) return true;
  }
  final moments = await (db.select(db.moments)
        ..where((t) => t.petId.equals(petId)))
      .get();
  for (final r in moments) {
    if (r.updatedAt.isAfter(since)) return true;
  }
  final expenses = await (db.select(db.expenses)
        ..where((t) => t.petId.equals(petId)))
      .get();
  for (final r in expenses) {
    if (r.updatedAt.isAfter(since)) return true;
  }
  return false;
}

/// 收集某宠物的快照（含墓碑；图片路径归一为文件名）。
SpaceSnapshot collectSnapshotRaw(
  Map<String, dynamic> petJson,
  List<Map<String, dynamic>> recordJsons,
  List<Map<String, dynamic>> momentJsons,
  List<Map<String, dynamic>> expenseJsons,
) {
  final images = <String>[];
  String norm(String path) {
    final name = p.basename(path);
    if (!images.contains(name)) images.add(name);
    return name;
  }

  List<Map<String, dynamic>> normList(List<Map<String, dynamic>> list) {
    final out = <Map<String, dynamic>>[];
    for (final j in list) {
      final m = Map<String, dynamic>.from(j);
      m['imagePaths'] = [
        for (final x in (m['imagePaths'] as List<dynamic>? ?? const []))
          norm(x.toString()),
      ];
      out.add(m);
    }
    return out;
  }

  final pet = Map<String, dynamic>.from(petJson);
  if (pet['avatarPath'] != null &&
      (pet['avatarPath'] as String).isNotEmpty) {
    pet['avatarPath'] = norm(pet['avatarPath'] as String);
  }
  return SpaceSnapshot(
    pet: pet,
    records: normList(recordJsons),
    moments: normList(momentJsons),
    expenses: normList(expenseJsons),
    imageNames: images,
  );
}

/// 数据库版收集。
Future<SpaceSnapshot> collectSnapshot(AppDatabase db, String petId) async {
  final petRow =
      await (db.select(db.pets)..where((t) => t.id.equals(petId))).getSingle();
  final records = await (db.select(db.healthRecords)
        ..where((t) => t.petId.equals(petId)))
      .get();
  final moments = await (db.select(db.moments)
        ..where((t) => t.petId.equals(petId)))
      .get();
  final expenses = await (db.select(db.expenses)
        ..where((t) => t.petId.equals(petId)))
      .get();
  return collectSnapshotRaw(
    AppDatabase.toPet(petRow).toJson(),
    [for (final r in records) AppDatabase.toHealthRecord(r).toJson()],
    [for (final r in moments) AppDatabase.toMoment(r).toJson()],
    [for (final r in expenses) AppDatabase.toExpense(r).toJson()],
  );
}

/// 把快照应用到数据库（LWW：updatedAt 新者胜；墓碑=删除同步）。
/// 返回宠物 id。
Future<String> applySnapshot(AppDatabase db, SpaceSnapshot snapshot) async {
  final dir = await ImageStore.imageDir();
  return applySnapshotIn(db, snapshot, dir.path);
}

/// 不依赖 path_provider 的版本（单测用，传入本机图片目录）。
Future<String> applySnapshotIn(
    AppDatabase db, SpaceSnapshot snapshot, String imagesDirPath) async {
  String localPath(String name) => p.join(imagesDirPath, name);

  List<String> mapPaths(dynamic v) => [
        for (final x in (v as List<dynamic>? ?? const []))
          localPath(p.basename(x.toString())),
      ];

  // 宠物（LWW）。
  final petJson = Map<String, dynamic>.from(snapshot.pet);
  final avatar = petJson['avatarPath'] as String?;
  if (avatar != null && avatar.isNotEmpty) {
    petJson['avatarPath'] = localPath(avatar);
  }
  final remotePet = Pet.fromJson(petJson);
  final localPetRow = await (db.select(db.pets)
        ..where((t) => t.id.equals(remotePet.id)))
      .get();
  if (localPetRow.isEmpty ||
      remotePet.updatedAt.isAfter(AppDatabase.toPet(localPetRow.first).updatedAt)) {
    await db
        .into(db.pets).insertOnConflictUpdate(AppDatabase.toPetsCompanion(remotePet));
  }

  for (final j in snapshot.records) {
    final m = Map<String, dynamic>.from(j);
    m['imagePaths'] = mapPaths(m['imagePaths']);
    final remote = HealthRecord.fromJson(m);
    final local = await (db.select(db.healthRecords)
          ..where((t) => t.id.equals(remote.id)))
        .get();
    if (local.isEmpty ||
        remote.updatedAt
            .isAfter(AppDatabase.toHealthRecord(local.first).updatedAt)) {
      await db.into(db.healthRecords).insertOnConflictUpdate(
          AppDatabase.toHealthRecordsCompanion(remote));
    }
  }
  for (final j in snapshot.moments) {
    final m = Map<String, dynamic>.from(j);
    m['imagePaths'] = mapPaths(m['imagePaths']);
    final remote = Moment.fromJson(m);
    final local = await (db.select(db.moments)
          ..where((t) => t.id.equals(remote.id)))
        .get();
    if (local.isEmpty ||
        remote.updatedAt.isAfter(AppDatabase.toMoment(local.first).updatedAt)) {
      await db
          .into(db.moments).insertOnConflictUpdate(AppDatabase.toMomentsCompanion(remote));
    }
  }
  for (final j in snapshot.expenses) {
    final m = Map<String, dynamic>.from(j);
    m['imagePaths'] = mapPaths(m['imagePaths']);
    final remote = Expense.fromJson(m);
    final local = await (db.select(db.expenses)
          ..where((t) => t.id.equals(remote.id)))
        .get();
    if (local.isEmpty ||
        remote.updatedAt
            .isAfter(AppDatabase.toExpense(local.first).updatedAt)) {
      await db.into(db.expenses)
          .insertOnConflictUpdate(AppDatabase.toExpensesCompanion(remote));
    }
  }
  return remotePet.id;
}
