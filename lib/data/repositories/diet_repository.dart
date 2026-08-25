import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/diet_profile.dart';
import '../../domain/models/meal_plan.dart';
import '../db/app_database.dart';

/// 饮食仓库：偏好 + 喂食计划。
class DietRepository {
  DietRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  // ---------- 偏好 ----------

  Stream<DietProfile?> watchProfile(String petId) {
    final query = _db.select(_db.dietProfiles)
      ..where((t) => t.petId.equals(petId));
    return query.watch().map((rows) =>
        rows.isEmpty ? null : AppDatabase.toDietProfile(rows.first));
  }

  Future<DietProfile?> getProfile(String petId) async {
    final query = _db.select(_db.dietProfiles)
      ..where((t) => t.petId.equals(petId));
    final rows = await query.get();
    return rows.isEmpty ? null : AppDatabase.toDietProfile(rows.first);
  }

  Future<void> saveProfile(DietProfile profile) async {
    await _db.into(_db.dietProfiles).insertOnConflictUpdate(
        AppDatabase.toDietProfilesCompanion(profile));
  }

  // ---------- 计划 ----------

  Future<MealPlan?> getPlanFor(String petId, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.mealPlans)
      ..where((t) =>
          t.petId.equals(petId) &
          t.date.equals(dayStart));
    final rows = await query.get();
    return rows.isEmpty ? null : AppDatabase.toMealPlan(rows.first);
  }

  /// 全部计划（按日期倒序）。
  Stream<List<MealPlan>> watchPlansByPet(String petId) {
    final query = _db.select(_db.mealPlans)
      ..where((t) => t.petId.equals(petId));
    return query.watch().map((rows) {
      final list = rows.map(AppDatabase.toMealPlan).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// 写入/覆盖某天的计划。
  Future<void> savePlan(MealPlan plan) async {
    final normalized = MealPlan(
      id: plan.id.isEmpty ? _uuid.v4() : plan.id,
      petId: plan.petId,
      date: DateTime(plan.date.year, plan.date.month, plan.date.day),
      source: plan.source,
      totalKcal: plan.totalKcal,
      waterMl: plan.waterMl,
      meals: plan.meals,
      advice: plan.advice,
      warnings: plan.warnings,
      repeatWeekly: plan.repeatWeekly,
      createdAt: plan.createdAt,
    );
    // 同一天已有计划则替换。
    final existing = await getPlanFor(normalized.petId, normalized.date);
    final toWrite = existing == null
        ? normalized
        : MealPlan(
            id: existing.id,
            petId: normalized.petId,
            date: normalized.date,
            source: normalized.source,
            totalKcal: normalized.totalKcal,
            waterMl: normalized.waterMl,
            meals: normalized.meals,
            advice: normalized.advice,
            warnings: normalized.warnings,
            repeatWeekly: normalized.repeatWeekly,
            createdAt: existing.createdAt,
          );
    await _db.into(_db.mealPlans).insertOnConflictUpdate(
        AppDatabase.toMealPlansCompanion(toWrite));
  }

  Future<void> deletePlan(String id) async {
    await (_db.delete(_db.mealPlans)..where((t) => t.id.equals(id))).go();
  }
}
