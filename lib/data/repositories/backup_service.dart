import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app/image_store.dart';
import '../../core/constants/app_info.dart';
import '../../domain/models/diet_profile.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/meal_plan.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../db/app_database.dart';
import 'diet_repository.dart';
import 'expense_repository.dart';
import 'health_record_repository.dart';
import 'moment_repository.dart';
import 'pet_repository.dart';
import 'settings_repository.dart';

/// 备份恢复：单文件 JSON（含图片 base64），恢复前自动写回滚备份。
class BackupService {
  BackupService(
    this._db,
    this._pets,
    this._health,
    this._moments,
    this._expenses,
    this._diet,
    this._settings,
  );

  final AppDatabase _db;
  final PetRepository _pets;
  final HealthRecordRepository _health;
  final MomentRepository _moments;
  final ExpenseRepository _expenses;
  final DietRepository _diet;
  final SettingsRepository _settings;

  /// 校验备份文件。返回错误信息，合法返回 null。
  String? validate(Map<String, dynamic> data) {
    final format = data['format'] as String?;
    if (format != AppInfo.backupFormat) return '不是有效的宠迹备份文件';
    final version = data['version'] as int? ?? 0;
    if (version > AppInfo.backupVersion) return '备份来自更新的版本，请先升级 App';
    return null;
  }

  Future<Map<String, dynamic>> _collect() async {
    final petRows = await _db.select(_db.pets).get();
    final healthRows = await _db.select(_db.healthRecords).get();
    final momentRows = await _db.select(_db.moments).get();
    final expenseRows = await _db.select(_db.expenses).get();
    final dietRows = await _db.select(_db.dietProfiles).get();
    final planRows = await _db.select(_db.mealPlans).get();

    final images = <String, String>{};
    void collect(List<String> paths) {
      for (final path in paths) {
        final file = File(path);
        // key 用文件名：恢复端可映射到本机图片目录，跨设备不丢图。
        final key = p.basename(path);
        if (file.existsSync() && !images.containsKey(key)) {
          try {
            images[key] = base64Encode(file.readAsBytesSync());
          } catch (_) {}
        }
      }
    }

    for (final row in petRows) {
      final pet = AppDatabase.toPet(row);
      if (pet.avatarPath != null) collect([pet.avatarPath!]);
    }
    for (final row in momentRows) {
      collect(AppDatabase.decodeList(row.imagePaths));
    }
    for (final row in healthRows) {
      collect(AppDatabase.decodeList(row.imagePaths));
    }
    for (final row in expenseRows) {
      collect(AppDatabase.decodeList(row.imagePaths));
    }

    return {
      'app': AppInfo.appName,
      'format': AppInfo.backupFormat,
      'version': AppInfo.backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'pets': petRows.map((r) => AppDatabase.toPet(r).toJson()).toList(),
      'healthRecords':
          healthRows.map((r) => AppDatabase.toHealthRecord(r).toJson()).toList(),
      'moments': momentRows.map((r) => AppDatabase.toMoment(r).toJson()).toList(),
      'expenses':
          expenseRows.map((r) => AppDatabase.toExpense(r).toJson()).toList(),
      'dietProfiles':
          dietRows.map((r) => AppDatabase.toDietProfile(r).toJson()).toList(),
      'mealPlans':
          planRows.map((r) => AppDatabase.toMealPlan(r).toJson()).toList(),
      'settings': await _settings.exportAll(),
      'images': images,
    };
  }

  /// 导出到临时目录并拉起系统分享。返回备份文件路径。
  Future<String> export() async {
    final data = await _collect();
    final dir = Directory.systemTemp;
    final name =
        'chongji-backup-${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await _settings.set(
        SettingsRepository.keyLastBackupAt, DateTime.now().toIso8601String());
    await Share.shareXFiles([XFile(file.path)],
        fileNameOverrides: [name]);
    return file.path;
  }

  /// 恢复。mode=overwrite 覆盖 / merge 按 id 合并。
  /// 恢复前自动把当前数据写入临时回滚备份，返回回滚文件路径。
  /// 图片统一落到本机图片目录，并把记录里的旧路径重映射为本机路径
  /// （备份来自其他设备时路径必然不同，直接照抄会全部失效）。
  Future<String?> restore(Map<String, dynamic> data,
      {bool overwrite = false}) async {
    String? rollbackPath;
    if (overwrite) {
      try {
        final current = await _collect();
        final file = File(p.join(Directory.systemTemp.path,
            'chongji-rollback-${DateTime.now().millisecondsSinceEpoch}.json'));
        await file.writeAsString(jsonEncode(current));
        rollbackPath = file.path;
      } catch (_) {}
    }

    // 1) 图片先落盘到本机图片目录，生成 旧路径/文件名 → 本机路径 映射。
    final images = data['images'] as Map<String, dynamic>? ?? {};
    final pathMap = await _materializeImages(images);

    await _db.transaction(() async {
      if (overwrite) {
        await _db.delete(_db.pets).go();
        await _db.delete(_db.healthRecords).go();
        await _db.delete(_db.moments).go();
        await _db.delete(_db.expenses).go();
        await _db.delete(_db.dietProfiles).go();
        await _db.delete(_db.mealPlans).go();
      }

      for (final raw in data['pets'] as List<dynamic>? ?? const []) {
        final json = raw as Map<String, dynamic>;
        json['avatarPath'] = remapPath(json['avatarPath'] as String?, pathMap);
        await _pets.upsert(Pet.fromJson(json));
      }
      for (final raw in data['healthRecords'] as List<dynamic>? ?? const []) {
        final json = raw as Map<String, dynamic>;
        json['imagePaths'] =
            remapPaths(castStringList(json['imagePaths']), pathMap);
        await _health.upsert(HealthRecord.fromJson(json));
      }
      for (final raw in data['moments'] as List<dynamic>? ?? const []) {
        final json = raw as Map<String, dynamic>;
        json['imagePaths'] =
            remapPaths(castStringList(json['imagePaths']), pathMap);
        await _moments.upsert(Moment.fromJson(json));
      }
      for (final raw in data['expenses'] as List<dynamic>? ?? const []) {
        final json = raw as Map<String, dynamic>;
        json['imagePaths'] =
            remapPaths(castStringList(json['imagePaths']), pathMap);
        await _expenses.upsert(Expense.fromJson(json));
      }
      for (final raw in data['dietProfiles'] as List<dynamic>? ?? const []) {
        await _diet.saveProfile(
            DietProfile.fromJson(raw as Map<String, dynamic>));
      }
      for (final raw in data['mealPlans'] as List<dynamic>? ?? const []) {
        await _diet.savePlan(MealPlan.fromJson(raw as Map<String, dynamic>));
      }
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        await _settings.importAll(
            settings.map((k, v) => MapEntry(k, v.toString())),
            overwrite: overwrite);
      }
    });
    return rollbackPath;
  }

  /// 把备份里的图片写到本机图片目录（文件名保持不变），
  /// 返回 "备份里的key（可能是绝对路径或文件名）→ 本机路径" 映射。
  /// 单张失败不中断。
  static Future<Map<String, String>> _materializeImages(
      Map<String, dynamic> images) async {
    final map = <String, String>{};
    Directory dir;
    try {
      dir = await ImageStore.imageDir();
    } catch (_) {
      return map;
    }
    for (final entry in images.entries) {
      try {
        final name = p.basename(entry.key);
        final target = p.join(dir.path, name);
        final f = File(target);
        if (!f.existsSync()) {
          await f.writeAsBytes(base64Decode(entry.value as String));
        }
        map[entry.key] = target;
        map[name] = target;
      } catch (_) {}
    }
    return map;
  }

  /// 单路径重映射：优先完整匹配，其次文件名匹配（跨设备备份），兜底原样。
  static String? remapPath(String? path, Map<String, String> map) {
    if (path == null || path.isEmpty) return path;
    return map[path] ?? map[p.basename(path)] ?? path;
  }

  /// 列表路径重映射。
  static List<String> remapPaths(List<String> paths, Map<String, String> map) =>
      [for (final x in paths) remapPath(x, map) ?? x];

  static List<String> castStringList(dynamic v) =>
      (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

  /// 全部被引用的图片路径（供图片清理用）。
  Future<Set<String>> referencedImages() async {
    final refs = <String>{};
    for (final pet in await _pets.getAll()) {
      if (pet.avatarPath != null) refs.add(pet.avatarPath!);
    }
    for (final m in await _moments.getAll()) {
      refs.addAll(m.imagePaths);
    }
    for (final e in await _expenses.getAll()) {
      refs.addAll(e.imagePaths);
    }
    final petIds = (await _pets.getAll()).map((e) => e.id).toSet();
    for (final id in petIds) {
      for (final r in await _health.getByPet(id)) {
        refs.addAll(r.imagePaths);
      }
    }
    return refs;
  }

  /// 消费明细 CSV 导出。[petNames] 用于把 petId 映射为名字。
  Future<String> exportCsv(
    List<Expense> expenses,
    Map<String, String> petNames,
  ) async {
    final buffer = StringBuffer('\uFEFF'); // BOM：Excel 中文兼容
    buffer.writeln('日期,宠物,分类,事项,金额(元),备注');
    final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    for (final e in sorted) {
      String csv(String s) =>
          s.contains(',') || s.contains('"') || s.contains('\n')
              ? '"${s.replaceAll('"', '""')}"'
              : s;
      buffer.writeln([
        '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}',
        csv(e.petId == null ? '全体' : (petNames[e.petId] ?? '')),
        csv(e.category.label),
        csv(e.title),
        (e.amount / 100).toStringAsFixed(2),
        csv(e.notes ?? ''),
      ].join(','));
    }
    final file = File(p.join(Directory.systemTemp.path,
        'chongji-expenses-${DateTime.now().millisecondsSinceEpoch}.csv'));
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)]);
    return file.path;
  }
}
