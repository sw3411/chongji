import 'package:chongji/data/db/app_database.dart';
import 'package:chongji/data/repositories/backup_service.dart';
import 'package:chongji/data/repositories/diet_repository.dart';
import 'package:chongji/data/repositories/expense_repository.dart';
import 'package:chongji/data/repositories/health_record_repository.dart';
import 'package:chongji/data/repositories/pet_repository.dart';
import 'package:chongji/domain/models/diet_profile.dart';
import 'package:chongji/domain/models/enums.dart';
import 'package:chongji/domain/models/expense.dart';
import 'package:chongji/domain/models/health_record.dart';
import 'package:chongji/domain/models/meal_plan.dart';
import 'package:chongji/domain/models/pet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PetRepository pets;
  late HealthRecordRepository health;
  late ExpenseRepository expenses;
  late DietRepository diet;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    pets = PetRepository(db);
    health = HealthRecordRepository(db);
    expenses = ExpenseRepository(db);
    diet = DietRepository(db);
  });

  tearDown(() async => db.close());

  Pet newPet() => Pet(
        id: 'pet-1',
        name: '豆豆',
        species: PetSpecies.dog,
        breed: '柴犬',
        birthday: DateTime(2024, 5, 1),
        gender: PetGender.male,
        neutered: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('宠物 + 健康记录往返', () async {
    await pets.upsert(newPet());
    final loaded = await pets.getById('pet-1');
    expect(loaded!.name, '豆豆');
    expect(loaded.species, PetSpecies.dog);
    expect(loaded.neutered, true);

    await health.upsert(HealthRecord(
      id: '',
      petId: 'pet-1',
      type: HealthRecordType.weight,
      date: DateTime(2026, 8, 1),
      value: 9.8,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    final records = await health.getByPet('pet-1');
    expect(records.length, 1);
    expect(records.first.value, 9.8);
    expect(records.first.id, isNotEmpty); // uuid 自动生成。
  });

  test('软删除过滤 + hardDelete 级联', () async {
    final pet = newPet();
    await pets.upsert(pet);
    await health.upsert(HealthRecord(
      id: 'r1',
      petId: 'pet-1',
      type: HealthRecordType.vaccine,
      date: DateTime(2026, 8, 1),
      textValue: '狂犬疫苗',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await expenses.upsert(Expense(
      id: 'e1',
      petId: 'pet-1',
      category: ExpenseCategory.medical,
      title: '疫苗',
      amount: 20000,
      date: DateTime(2026, 8, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));

    await pets.hardDelete('pet-1');
    expect(await pets.getById('pet-1'), isNull);
    expect((await health.getByPet('pet-1')), isEmpty);
    // 消费保留，petId 置空（无归属）。
    final all = await expenses.getAll();
    expect(all.length, 1);
    expect(all.first.petId, isNull);
  });

  test('饮食偏好与喂食计划：同日覆盖', () async {
    await pets.upsert(newPet());
    await diet.saveProfile(DietProfile(
      petId: 'pet-1',
      foodType: FoodType.mixed,
      likes: const ['鸡肉'],
      allergens: const ['牛肉'],
      mealsPerDay: 3,
      updatedAt: DateTime(2026, 1, 1),
    ));
    final profile = await diet.getProfile('pet-1');
    expect(profile!.foodType, FoodType.mixed);
    expect(profile.likes, ['鸡肉']);
    expect(profile.allergens, ['牛肉']);
    expect(profile.mealsPerDay, 3);

    MealPlan plan(DateTime date) => MealPlan(
          id: '',
          petId: 'pet-1',
          date: date,
          source: PlanSource.ai,
          totalKcal: 620,
          meals: [
            PlanMeal(
                time: '08:00', name: '早餐', grams: 120, kcal: 310),
          ],
          advice: '多喝水',
          createdAt: DateTime(2026, 1, 1),
        );

    // 同一天两次保存 → 替换不重复。
    await diet.savePlan(plan(DateTime(2026, 8, 26, 15, 30)));
    await diet.savePlan(plan(DateTime(2026, 8, 26, 9, 0)));
    final saved = await diet.getPlanFor('pet-1', DateTime(2026, 8, 26));
    expect(saved, isNotNull);
    expect(saved!.totalKcal, 620);
    expect(saved.date, DateTime(2026, 8, 26)); // 日期归一到当天。
    final plans = await diet.watchPlansByPet('pet-1').first;
    expect(plans.length, 1);
  });

  test('模型 toJson/fromJson 往返', () {
    final pet = newPet().toJson();
    final restored = Pet.fromJson(pet);
    expect(restored.name, '豆豆');
    expect(restored.birthday, DateTime(2024, 5, 1));

    final plan = MealPlan(
      id: 'pl1',
      petId: 'pet-1',
      date: DateTime(2026, 8, 26),
      source: PlanSource.ai,
      totalKcal: 600,
      meals: [
        PlanMeal(
          time: '08:00',
          name: '鲜食餐',
          items: const ['鸡胸肉 100g'],
          ingredients: const ['鸡胸肉 100g', '西兰花 30g'],
          steps: const ['水煮 15 分钟'],
        ),
      ],
      warnings: const ['避免葡萄'],
      createdAt: DateTime(2026, 1, 1),
    );
    final restoredPlan = MealPlan.fromJson(plan.toJson());
    expect(restoredPlan.meals.length, 1);
    expect(restoredPlan.meals.first.ingredients.length, 2);
    expect(restoredPlan.warnings, ['避免葡萄']);
  });

  test('备份图片路径重映射（跨设备恢复）', () {
    final map = {
      // 旧版备份以绝对路径为 key；新版以文件名为 key。两种都应命中。
      '/old/device/Documents/images/abc.jpg': '/local/images/abc.jpg',
      'abc.jpg': '/local/images/abc.jpg',
      'zzz.png': '/local/images/zzz.png',
    };
    // 完整路径命中。
    expect(BackupService.remapPath('/old/device/Documents/images/abc.jpg', map),
        '/local/images/abc.jpg');
    // basename 命中。
    expect(
        BackupService.remapPath('/somewhere/else/abc.jpg', map),
        '/local/images/abc.jpg');
    // 未知路径兜底原样返回，null 安全。
    expect(BackupService.remapPath('/unknown/x.png', map), '/unknown/x.png');
    expect(BackupService.remapPath(null, map), isNull);
    expect(BackupService.remapPath('', map), '');
    // 列表重映射。
    expect(
      BackupService.remapPaths(
          ['/old/device/Documents/images/abc.jpg', 'zzz.png', 'nope'], map),
      ['/local/images/abc.jpg', '/local/images/zzz.png', 'nope'],
    );
  });
}
