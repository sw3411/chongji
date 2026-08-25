import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/diet_profile.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/meal_plan.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/cloud_space.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 主数据库。表结构见 tables.dart，行对象命名为 *Row。
@DriftDatabase(tables: [
  Pets,
  HealthRecords,
  Moments,
  Expenses,
  DietProfiles,
  MealPlans,
  CloudSpaces,
  ChatSessions,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'chongji'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // 数据库升级：保持 from <= N 风格逐级迁移，保证老数据不丢。
          if (from <= 1) {
            // v2：到家日期（与生日分开，两者都作为纪念日提醒）。
            await m.addColumn(pets, pets.adoptionDate);
          }
          if (from <= 2) {
            // v3：云同步墓碑（软删除）+ 云空间绑定表。
            await m.addColumn(healthRecords, healthRecords.deletedAt);
            await m.addColumn(moments, moments.deletedAt);
            await m.addColumn(expenses, expenses.deletedAt);
            await m.createTable(cloudSpaces);
          }
          if (from <= 3) {
            // v4：AI 对话会话持久化。
            await m.createTable(chatSessions);
          }
        },
      );

  // ---------- 行 → 领域对象 ----------

  static Pet toPet(PetRow r) => Pet(
        id: r.id,
        name: r.name,
        species: PetSpecies.fromName(r.species),
        breed: r.breed,
        birthday: r.birthday,
        adoptionDate: r.adoptionDate,
        gender: PetGender.fromName(r.gender),
        neutered: r.neutered,
        avatarPath: r.avatarPath,
        notes: r.notes,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );

  static PetsCompanion toPetsCompanion(Pet p) => PetsCompanion(
        id: Value(p.id),
        name: Value(p.name),
        species: Value(p.species.name),
        breed: Value(p.breed),
        birthday: Value(p.birthday),
        adoptionDate: Value(p.adoptionDate),
        gender: Value(p.gender.name),
        neutered: Value(p.neutered),
        avatarPath: Value(p.avatarPath),
        notes: Value(p.notes),
        createdAt: Value(p.createdAt),
        updatedAt: Value(p.updatedAt),
        deletedAt: Value(p.deletedAt),
      );

  static HealthRecord toHealthRecord(HealthRecordRow r) => HealthRecord(
        id: r.id,
        petId: r.petId,
        type: HealthRecordType.fromName(r.type),
        date: r.date,
        value: r.value,
        textValue: r.textValue,
        diagnosis: r.diagnosis,
        cycleDays: r.cycleDays,
        notes: r.notes,
        imagePaths: decodeList(r.imagePaths),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );

  static HealthRecordsCompanion toHealthRecordsCompanion(HealthRecord r) =>
      HealthRecordsCompanion(
        id: Value(r.id),
        petId: Value(r.petId),
        type: Value(r.type.name),
        date: Value(r.date),
        value: Value(r.value),
        textValue: Value(r.textValue),
        diagnosis: Value(r.diagnosis),
        cycleDays: Value(r.cycleDays),
        notes: Value(r.notes),
        imagePaths: Value(jsonEncode(r.imagePaths)),
        createdAt: Value(r.createdAt),
        updatedAt: Value(r.updatedAt),
        deletedAt: Value(r.deletedAt),
      );

  static Moment toMoment(MomentRow r) => Moment(
        id: r.id,
        petId: r.petId,
        type: MomentType.fromName(r.type),
        date: r.date,
        title: r.title,
        notes: r.notes,
        location: r.location,
        imagePaths: decodeList(r.imagePaths),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );

  static MomentsCompanion toMomentsCompanion(Moment m) => MomentsCompanion(
        id: Value(m.id),
        petId: Value(m.petId),
        type: Value(m.type.name),
        date: Value(m.date),
        title: Value(m.title),
        notes: Value(m.notes),
        location: Value(m.location),
        imagePaths: Value(jsonEncode(m.imagePaths)),
        createdAt: Value(m.createdAt),
        updatedAt: Value(m.updatedAt),
        deletedAt: Value(m.deletedAt),
      );

  static Expense toExpense(ExpenseRow r) => Expense(
        id: r.id,
        petId: r.petId,
        category: ExpenseCategory.fromName(r.category),
        title: r.title,
        amount: r.amount,
        date: r.date,
        notes: r.notes,
        imagePaths: decodeList(r.imagePaths),
        relatedRecordId: r.relatedRecordId,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );

  static ExpensesCompanion toExpensesCompanion(Expense e) =>
      ExpensesCompanion(
        id: Value(e.id),
        petId: Value(e.petId),
        category: Value(e.category.name),
        title: Value(e.title),
        amount: Value(e.amount),
        date: Value(e.date),
        notes: Value(e.notes),
        imagePaths: Value(jsonEncode(e.imagePaths)),
        relatedRecordId: Value(e.relatedRecordId),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
        deletedAt: Value(e.deletedAt),
      );

  static DietProfile toDietProfile(DietProfileRow r) => DietProfile(
        petId: r.petId,
        foodType: FoodType.fromName(r.foodType),
        brand: r.brand,
        likes: decodeList(r.likes),
        dislikes: decodeList(r.dislikes),
        allergens: decodeList(r.allergens),
        mealsPerDay: r.mealsPerDay,
        notes: r.notes,
        updatedAt: r.updatedAt,
      );

  static DietProfilesCompanion toDietProfilesCompanion(DietProfile d) =>
      DietProfilesCompanion(
        petId: Value(d.petId),
        foodType: Value(d.foodType.name),
        brand: Value(d.brand),
        likes: Value(jsonEncode(d.likes)),
        dislikes: Value(jsonEncode(d.dislikes)),
        allergens: Value(jsonEncode(d.allergens)),
        mealsPerDay: Value(d.mealsPerDay),
        notes: Value(d.notes),
        updatedAt: Value(d.updatedAt),
      );

  static MealPlan toMealPlan(MealPlanRow r) {
    Map<String, dynamic> content;
    try {
      content = jsonDecode(r.content) as Map<String, dynamic>;
    } catch (_) {
      content = {};
    }
    return MealPlan(
      id: r.id,
      petId: r.petId,
      date: r.date,
      source: PlanSource.fromName(r.source),
      totalKcal: (content['totalKcal'] as num?)?.toDouble(),
      waterMl: (content['waterMl'] as num?)?.toDouble(),
      meals: (content['meals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlanMeal.fromJson)
          .toList(),
      advice: content['advice'] as String?,
      warnings: (content['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      repeatWeekly: content['repeatWeekly'] as bool? ?? false,
      createdAt: r.createdAt,
    );
  }

  static MealPlansCompanion toMealPlansCompanion(MealPlan p) =>
      MealPlansCompanion(
        id: Value(p.id),
        petId: Value(p.petId),
        date: Value(p.date),
        source: Value(p.source.name),
        content: Value(jsonEncode({
          'totalKcal': p.totalKcal,
          'waterMl': p.waterMl,
          'meals': p.meals.map((m) => m.toJson()).toList(),
          'advice': p.advice,
          'warnings': p.warnings,
          'repeatWeekly': p.repeatWeekly,
        })),
        createdAt: Value(p.createdAt),
      );

  static ChatSession toChatSession(ChatSessionRow r) => ChatSession(
        id: r.id,
        title: r.title,
        petId: r.petId,
        petName: r.petName,
        messages: _decodeMessages(r.messagesJson),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static ChatSessionsCompanion toChatSessionsCompanion(ChatSession s) =>
      ChatSessionsCompanion(
        id: Value(s.id),
        title: Value(s.title),
        petId: Value(s.petId),
        petName: Value(s.petName),
        messageCount: Value(s.messages.length),
        messagesJson: Value(jsonEncode(
            [for (final m in s.messages) m.toJson()])),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
      );

  static List<ChatMessage> _decodeMessages(String json) {
    if (json.isEmpty) return const [];
    try {
      return (jsonDecode(json) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static CloudSpace toCloudSpace(CloudSpaceRow r) => CloudSpace(
        petId: r.petId,
        code: r.code,
        endpoint: r.endpoint,
        bucket: r.bucket,
        role: r.role,
        memberName: r.memberName,
        accessKey: r.accessKey,
        secretKey: r.secretKey,
        lastVersion: r.lastVersion,
        lastSyncAt: r.lastSyncAt,
        createdAt: r.createdAt,
      );

  static CloudSpacesCompanion toCloudSpacesCompanion(CloudSpace s) =>
      CloudSpacesCompanion(
        petId: Value(s.petId),
        code: Value(s.code),
        endpoint: Value(s.endpoint),
        bucket: Value(s.bucket),
        role: Value(s.role),
        memberName: Value(s.memberName),
        accessKey: Value(s.accessKey),
        secretKey: Value(s.secretKey),
        lastVersion: Value(s.lastVersion),
        lastSyncAt: Value(s.lastSyncAt),
        createdAt: Value(s.createdAt),
      );

  /// 容错解析 JSON 文本列。
  static List<String> decodeList(String json) {
    if (json.isEmpty) return const [];
    try {
      final l = jsonDecode(json) as List<dynamic>;
      return l.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }
}
