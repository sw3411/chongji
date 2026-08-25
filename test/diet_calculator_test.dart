import 'package:flutter_test/flutter_test.dart';
import 'package:chongji/domain/models/enums.dart';
import 'package:chongji/domain/models/meal_plan.dart';
import 'package:chongji/domain/models/pet.dart';
import 'package:chongji/domain/services/diet_calculator.dart';

import 'health_calculator_test.dart' show rec, pet;

void main() {
  group('rer', () {
    test('10kg 犬 RER ≈ 394', () {
      expect(DietCalculator.rer(10), closeTo(393.6, 1.0));
    });

    test('5kg 猫 RER ≈ 234', () {
      expect(DietCalculator.rer(5), closeTo(233.8, 1.0));
    });
  });

  group('dailyFactor', () {
    test('幼犬系数最高', () {
      expect(
          DietCalculator.dailyFactor(
              species: PetSpecies.dog,
              lifeStage: '幼年（4个月以下）',
              neutered: false),
          3.0);
    });

    test('绝育成年犬 1.6 / 未绝育 1.8', () {
      expect(
          DietCalculator.dailyFactor(
              species: PetSpecies.dog,
              lifeStage: '成年',
              neutered: true),
          1.6);
      expect(
          DietCalculator.dailyFactor(
              species: PetSpecies.dog,
              lifeStage: '成年',
              neutered: false),
          1.8);
    });

    test('BCS>=6 减肥系数', () {
      expect(
          DietCalculator.dailyFactor(
              species: PetSpecies.dog,
              lifeStage: '成年',
              neutered: true,
              bcs: 7),
          1.0);
    });

    test('绝育猫 1.2', () {
      expect(
          DietCalculator.dailyFactor(
              species: PetSpecies.cat,
              lifeStage: '成年',
              neutered: true),
          1.2);
    });
  });

  group('dailyKcal', () {
    test('10kg 绝育成年犬 ≈ 630 kcal', () {
      final p = pet(birthday: DateTime(2022, 1, 1)); // 成年（helper 默认已绝育）
      final records = [
        rec(HealthRecordType.weight, DateTime(2026, 8, 1), value: 10),
        rec(HealthRecordType.bcs, DateTime(2026, 8, 1), value: 5),
      ];
      final kcal = DietCalculator.dailyKcal(p, records);
      expect(kcal, isNotNull);
      expect(kcal!, closeTo(393.6 * 1.6, 2.0));
    });

    test('无体重时用品种典型体重兜底', () {
      final p = Pet(
        id: 'p1',
        name: '咪咪',
        species: PetSpecies.cat,
        breed: '英国短毛猫',
        birthday: DateTime(2022, 1, 1),
        neutered: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final kcal = DietCalculator.dailyKcal(p, [], breedTypicalKg: 6.0);
      expect(kcal, isNotNull);
      expect(kcal!, greaterThan(200));
    });

    test('完全无数据返回 null', () {
      final p = pet(birthday: DateTime(2022, 1, 1));
      expect(DietCalculator.dailyKcal(p, []), isNull);
    });
  });

  group('effectivePlan 周循环', () {
    MealPlan plan(DateTime date, {bool repeat = false}) => MealPlan(
          id: '${date.toIso8601String()}-$repeat',
          petId: 'p1',
          date: date,
          source: PlanSource.ai,
          totalKcal: 500,
          repeatWeekly: repeat,
          createdAt: DateTime(2026, 1, 1),
        );

    test('当天精确匹配优先', () {
      final exact = plan(DateTime(2026, 8, 26));
      final tpl = plan(DateTime(2026, 8, 25), repeat: true); // 同周二的模板
      final got =
          DietCalculator.effectivePlan([exact, tpl], DateTime(2026, 8, 26));
      expect(got!.id, exact.id);
    });

    test('无当天计划时落到同星期周循环模板', () {
      // 2026-8-26 是周三；模板 2026-8-19 也是周三。
      final tpl = plan(DateTime(2026, 8, 19), repeat: true);
      final got =
          DietCalculator.effectivePlan([tpl], DateTime(2026, 8, 26));
      expect(got!.id, tpl.id);
    });

    test('非循环计划不外推，未来模板不提前生效', () {
      final once = plan(DateTime(2026, 8, 20));
      expect(DietCalculator.effectivePlan([once], DateTime(2026, 8, 27)),
          isNull);
      // 未来日期的循环模板不能用于过去查询。
      final future = plan(DateTime(2026, 9, 2), repeat: true);
      expect(
          DietCalculator.effectivePlan([future], DateTime(2026, 8, 26)), isNull);
    });
  });

  group('splitMeals / kibbleGrams / waterMl', () {
    test('均分热量', () {
      final meals = DietCalculator.splitMeals(500, 2);
      expect(meals, [250.0, 250.0]);
      // 顿数至少为 1。
      expect(DietCalculator.splitMeals(300, 0).length, 1);
    });

    test('干粮克数', () {
      expect(DietCalculator.kibbleGrams(360), closeTo(100.0, 0.01));
    });

    test('饮水量', () {
      expect(DietCalculator.waterMl(10, PetSpecies.dog), 550);
      expect(DietCalculator.waterMl(4, PetSpecies.cat), 200);
    });
  });
}
