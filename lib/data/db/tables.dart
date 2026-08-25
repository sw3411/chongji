import 'package:drift/drift.dart';

/// 宠物表。列表字段以 JSON 文本存储；软删除（deletedAt）。
@DataClassName('PetRow')
class Pets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get species => text()();
  TextColumn get breed => text().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
  DateTimeColumn get adoptionDate => dateTime().nullable()();
  TextColumn get gender => text().withDefault(const Constant('unknown'))();
  BoolColumn get neutered => boolean().withDefault(const Constant(false))();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 健康记录表。value=体重kg或BCS分；textValue=疫苗名/药名/医院名。
/// deletedAt = 云同步墓碑（软删除，保留 365 天供其他设备同步删除语义）。
@DataClassName('HealthRecordRow')
class HealthRecords extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text()();
  TextColumn get type => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get value => real().nullable()();
  TextColumn get textValue => text().nullable()();
  TextColumn get diagnosis => text().nullable()();
  IntColumn get cycleDays => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePaths => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 时刻表。
@DataClassName('MomentRow')
class Moments extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text()();
  TextColumn get type => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get imagePaths => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 消费表。金额以分（int）存储；petId 为空 = 全体宠物（不参与云空间同步）。
@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text().nullable()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePaths => text().withDefault(const Constant('[]'))();
  TextColumn get relatedRecordId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 云空间表：每只宠物最多一个空间绑定（petId 即主键）。
/// dataKey 不落库，存系统钥匙串（见 SpaceSync）。
@DataClassName('CloudSpaceRow')
class CloudSpaces extends Table {
  TextColumn get petId => text()();
  /// 空间暗号（如 CJ-XXXX-XXXX-XXXX-XXXX），同时也是对象前缀。
  TextColumn get code => text()();
  TextColumn get endpoint => text()();
  TextColumn get bucket => text()();
  /// 我的角色：manage / edit / view。
  TextColumn get role => text()();
  TextColumn get memberName => text()();
  /// 写入用 AK/SK；查看者为空串（公共读桶直接拉取）。
  TextColumn get accessKey => text().withDefault(const Constant(''))();
  TextColumn get secretKey => text().withDefault(const Constant(''))();
  IntColumn get lastVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {petId};
}

/// 饮食偏好表（每只宠物一份，petId 即主键）。
@DataClassName('DietProfileRow')
class DietProfiles extends Table {
  TextColumn get petId => text()();
  TextColumn get foodType => text().withDefault(const Constant('mixed'))();
  TextColumn get brand => text().nullable()();
  TextColumn get likes => text().withDefault(const Constant('[]'))();
  TextColumn get dislikes => text().withDefault(const Constant('[]'))();
  TextColumn get allergens => text().withDefault(const Constant('[]'))();
  IntColumn get mealsPerDay => integer().withDefault(const Constant(2))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {petId};
}

/// 喂食计划表。content 为 JSON（总热量 + 每餐明细 + 建议）。
@DataClassName('MealPlanRow')
class MealPlans extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get content => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// AI 对话会话表：一个会话一行，消息整存整取（JSON）。
@DataClassName('ChatSessionRow')
class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get petId => text()();
  TextColumn get petName => text()();
  IntColumn get messageCount => integer()();
  TextColumn get messagesJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 键值设置表。
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
