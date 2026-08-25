import 'dart:math' as math;

import '../models/health_record.dart';
import '../models/meal_plan.dart';
import '../models/pet.dart';
import '../models/enums.dart';
import 'health_calculator.dart';

/// 饮食估算：静息能量需求 RER 与每日热量。
/// 公式来自兽医营养学常用经验公式，仅作起始参考——
/// 实际喂量请结合体况变化调整，AI 生成计划时也会参考该估算。
class DietCalculator {
  DietCalculator._();

  /// RER = 70 × 体重(kg)^0.75。
  static double rer(double weightKg) => 70 * math.pow(weightKg, 0.75).toDouble();

  /// 每日热量系数（按生活阶段 / 绝育 / 体况）。
  static double dailyFactor({
    required PetSpecies species,
    required String lifeStage,
    required bool neutered,
    int? bcs,
  }) {
    final overweight = (bcs ?? 5) >= 6;
    if (lifeStage.contains('幼年')) {
      return lifeStage.contains('4个月以下') ? 3.0 : 2.0;
    }
    if (overweight) return 1.0;
    if (species == PetSpecies.cat) return neutered ? 1.2 : 1.4;
    return neutered ? 1.6 : 1.8;
  }

  /// 每日建议热量（kcal）。体重缺失时用品种典型体重中值。
  static double? dailyKcal(
    Pet pet,
    List<HealthRecord> records, {
    double? breedTypicalKg,
  }) {
    final w = HealthCalculator.latestWeight(records)?.value ?? breedTypicalKg;
    if (w == null || w <= 0) return null;
    final stage = HealthCalculator.lifeStage(pet.birthday, pet.species);
    final bcs = HealthCalculator.latestBcs(records)?.value?.toInt();
    final factor = dailyFactor(
      species: pet.species,
      lifeStage: stage,
      neutered: pet.neutered,
      bcs: bcs,
    );
    return rer(w) * factor;
  }

  /// 按顿拆分热量。
  static List<double> splitMeals(double totalKcal, int mealsPerDay) {
    final n = math.max(1, mealsPerDay);
    // 正餐均分（保留 1 位小数）。
    final each = (totalKcal / n * 10).roundToDouble() / 10;
    return List.filled(n, each);
  }

  /// 干粮克数估算（干粮约 3.6 kcal/g）。
  static double kibbleGrams(double kcal) => (kcal / 3.6 * 10).roundToDouble() / 10;

  /// 饮水建议（ml/kg/天：狗 50-60，猫 40-60，取中值）。
  static double waterMl(double weightKg, PetSpecies species) {
    final perKg = species == PetSpecies.cat ? 50.0 : 55.0;
    return (weightKg * perKg).roundToDouble();
  }

  /// 查某天生效的计划：优先当天精确匹配；
  /// 否则用「周循环模板」（同星期、repeatWeekly、日期不晚于查询日）里最近的一份。
  static MealPlan? effectivePlan(List<MealPlan> plans, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final p in plans) {
      if (p.date.year == day.year &&
          p.date.month == day.month &&
          p.date.day == day.day) {
        return p;
      }
    }
    MealPlan? best;
    for (final p in plans) {
      if (!p.repeatWeekly) continue;
      if (p.date.weekday != day.weekday) continue;
      final isAfter = p.date.isAfter(day);
      if (isAfter) continue;
      if (best == null || p.date.isAfter(best.date)) best = p;
    }
    return best;
  }
}
