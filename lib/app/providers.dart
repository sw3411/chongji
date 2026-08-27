import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/ai/ai_client.dart';
import '../core/notifications/notification_service.dart';
import '../core/ai/ai_config.dart';
import '../core/ai/ai_service.dart';
import '../data/db/app_database.dart';
import '../data/repositories/backup_service.dart';
import '../data/repositories/diet_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/health_record_repository.dart';
import '../data/repositories/moment_repository.dart';
import '../data/repositories/pet_repository.dart';
import '../core/cloud/space_sync.dart';
import '../data/repositories/chat_session_repository.dart';
import '../domain/models/chat_session.dart';
import '../data/repositories/cloud_space_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/models/cloud_space.dart';
import '../domain/models/diet_profile.dart';
import '../domain/models/expense.dart';
import '../domain/models/health_record.dart';
import '../domain/models/moment.dart';
import '../domain/models/pet.dart';
import '../domain/services/health_calculator.dart';
import '../shared/widgets/common.dart';
import 'app_settings.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());

final petRepoProvider =
    Provider<PetRepository>((ref) => PetRepository(ref.read(dbProvider)));
final healthRepoProvider = Provider<HealthRecordRepository>(
    (ref) => HealthRecordRepository(ref.read(dbProvider)));
final momentRepoProvider = Provider<MomentRepository>(
    (ref) => MomentRepository(ref.read(dbProvider)));
final expenseRepoProvider = Provider<ExpenseRepository>(
    (ref) => ExpenseRepository(ref.read(dbProvider)));
final dietRepoProvider =
    Provider<DietRepository>((ref) => DietRepository(ref.read(dbProvider)));
final settingsRepoProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.read(dbProvider)));

final cloudSpaceRepoProvider = Provider<CloudSpaceRepository>(
    (ref) => CloudSpaceRepository(ref.read(dbProvider)));

final chatSessionRepoProvider = Provider<ChatSessionRepository>(
    (ref) => ChatSessionRepository(ref.read(dbProvider)));

final chatSessionsProvider = StreamProvider<List<ChatSession>>(
    (ref) => ref.watch(chatSessionRepoProvider).watchAll());

final cloudSpacesProvider = StreamProvider<List<CloudSpace>>(
    (ref) => ref.watch(cloudSpaceRepoProvider).watchAll());

final spaceSyncProvider = Provider<SpaceSync>(
    (ref) => SpaceSync(ref.read(dbProvider), ref.read(cloudSpaceRepoProvider)));

/// 某宠物的云空间角色（null = 未开启共享）。
String? cloudRoleOf(WidgetRef ref, String? petId) {
  if (petId == null) return null;
  final spaces = ref.watch(cloudSpacesProvider).valueOrNull ?? const <CloudSpace>[];
  for (final s in spaces) {
    if (s.petId == petId) return s.role;
  }
  return null;
}

/// 该宠物是否为「共享只读」（查看者），写操作前统一拦截。
bool cloudReadOnly(WidgetRef ref, String? petId) =>
    cloudRoleOf(ref, petId) == 'view';

/// 该宠物若开启了云空间，保存后自动同步（有修改才推，静默失败）。
Future<void> autoPushIfNeeded(WidgetRef ref, String? petId) async {
  if (petId == null) return;
  final spaces = ref.read(cloudSpacesProvider).valueOrNull ?? const [];
  for (final s in spaces) {
    if (s.petId == petId && s.canWrite && s.hasCredentials) {
      try {
        await ref.read(spaceSyncProvider).sync(s);
      } catch (_) {}
    }
  }
}

/// 写操作前的统一入口：
/// 1) 共享只读（查看角色）→ 提示并返回 false；
/// 2) 可写 → 先静默拉取一次远端最新（修改前同步），失败不阻塞本地保存。
Future<bool> ensureWritable(
    WidgetRef ref, BuildContext context, String? petId) async {
  final spaces = ref.watch(cloudSpacesProvider).valueOrNull ?? const [];
  CloudSpace? space;
  for (final s in spaces) {
    if (s.petId == petId) space = s;
  }
  if (space == null) return true; // 未开启共享，本地随意写
  if (!space.canWrite) {
    showAutoToast(context, '该宠物为共享只读（查看权限），不能修改');
    return false;
  }
  try {
    await ref.read(spaceSyncProvider).pull(space);
  } catch (_) {} // 拉取失败不阻塞：冲突留给下次同步合并
  return true;
}

/// 手动同步的忙碌状态（SyncButton 用）。
final syncBusyProvider = StateProvider<bool>((ref) => false);

/// 手动同步当前宠物：无空间提示、有空间则「拉取 + 有修改才推」。
Future<void> manualSyncCurrentPet(WidgetRef ref, BuildContext context) async {
  final pet = ref.read(currentPetProvider);
  if (pet == null) {
    showAutoToast(context, '请先添加宠物');
    return;
  }
  final spaces = ref.read(cloudSpacesProvider).valueOrNull ?? const [];
  CloudSpace? space;
  for (final s in spaces) {
    if (s.petId == pet.id) space = s;
  }
  if (space == null) {
    showAutoToast(context, '该宠物未开启云空间（设置 → 云空间）');
    return;
  }
  ref.read(syncBusyProvider.notifier).state = true;
  try {
    final outcome = await ref.read(spaceSyncProvider).sync(space);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    showAutoToast(context, switch (outcome) {
      SyncOutcome.pushed => '已同步并推送最新修改 ✅',
      SyncOutcome.pulled => '已拉取最新数据（本地无修改）',
      SyncOutcome.upToDate => '已是最新，无修改不同步',
    });
  } catch (e) {
    if (context.mounted) showAutoToast(context, '同步失败：$e');
  } finally {
    ref.read(syncBusyProvider.notifier).state = false;
  }
}

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      ref.read(dbProvider),
      ref.read(petRepoProvider),
      ref.read(healthRepoProvider),
      ref.read(momentRepoProvider),
      ref.read(expenseRepoProvider),
      ref.read(dietRepoProvider),
      ref.read(settingsRepoProvider),
    ));

// ---------- 设置 ----------

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier(ref.read(settingsRepoProvider)));

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._repo) : super(AppSettings()) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    state = await AppSettingsController(_repo).load();
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await AppSettingsController(_repo).save(settings);
  }
}

/// 兼容 Ref/WidgetRef 的读取器。
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// 按当前设置与全部宠物数据，重排「每日提醒摘要」通知。
Future<void> rescheduleDailyDigest(ProviderReader read) async {
  final settings = read(appSettingsProvider);
  if (!settings.reminderEnabled || !settings.dailyDigestEnabled) {
    await NotificationService.syncDailyDigest(
        enabled: false, hour: 9, title: '', body: '');
    return;
  }
  final pets = await read(petRepoProvider).getAll();
  final map = <Pet, List<HealthRecord>>{};
  for (final p in pets.where((p) => !p.isDeleted)) {
    map[p] = await read(healthRepoProvider).getByPet(p.id);
  }
  final (title, body) = dailyDigestText(map);
  await NotificationService.syncDailyDigest(
    enabled: true,
    hour: settings.dailyDigestHour,
    title: title,
    body: body,
  );
}

// ---------- 宠物 ----------

// ---------- 首页轮播图 ----------

/// 首页顶部轮播图上限。
const int kHeroCarouselMax = 30;

/// 首页轮播图存储 key（settings 表单键，内含每宠一份）。
const String _kHeroCarouselKey = 'heroCarousel';

/// 每宠轮播图：{petId: [图片路径]}；头像始终为首页第一张、不在此列。
class HeroCarouselNotifier extends StateNotifier<Map<String, List<String>>> {
  HeroCarouselNotifier(this._repo) : super(const <String, List<String>>{}) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    final json = await _repo.getJson(_kHeroCarouselKey);
    if (json == null || !mounted) return;
    final pets = (json['pets'] as Map<String, dynamic>?) ?? const {};
    state = pets.map((k, v) =>
        MapEntry(k, (v as List).cast<String>()));
  }

  /// 覆盖某宠的轮播图并持久化。
  Future<void> setFor(String petId, List<String> paths) async {
    final next = Map<String, List<String>>.from(state);
    if (paths.isEmpty) {
      next.remove(petId);
    } else {
      next[petId] = paths.take(kHeroCarouselMax).toList();
    }
    state = next;
    await _repo.setJson(_kHeroCarouselKey,
        {'pets': next.map((k, v) => MapEntry(k, v))});
  }

  Future<void> addFor(String petId, List<String> newPaths) async {
    final merged = [...(state[petId] ?? const <String>[]), ...newPaths]
        .take(kHeroCarouselMax)
        .toList();
    await setFor(petId, merged);
  }

  Future<void> removeAt(String petId, int index) async {
    final list = [...(state[petId] ?? const <String>[])];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await setFor(petId, list);
  }
}

final heroCarouselProvider =
    StateNotifierProvider<HeroCarouselNotifier, Map<String, List<String>>>(
        (ref) => HeroCarouselNotifier(ref.read(settingsRepoProvider)));

/// 全部宠物（未删除）。
final petsProvider = StreamProvider<List<Pet>>((ref) {
  return ref.watch(petRepoProvider).watchAll().map(
      (pets) => pets.where((p) => !p.isDeleted).toList());
});

/// 当前选中宠物 id（持久化保存用户选择）。
final currentPetIdProvider = StateNotifierProvider<CurrentPetNotifier, String?>(
    (ref) => CurrentPetNotifier(ref.read(settingsRepoProvider)));

class CurrentPetNotifier extends StateNotifier<String?> {
  CurrentPetNotifier(this._repo) : super(null) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    final saved = await _repo.get(SettingsRepository.keyCurrentPetId);
    if (saved != null) state = saved;
  }

  void select(String id) {
    state = id;
    _repo.set(SettingsRepository.keyCurrentPetId, id);
  }
}

/// 当前宠物对象：优先用户选择；选中宠物被删除/为空时回退到第一只。
final currentPetProvider = Provider<Pet?>((ref) {
  final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
  final id = ref.watch(currentPetIdProvider);
  for (final p in pets) {
    if (p.id == id) return p;
  }
  return pets.isEmpty ? null : pets.first;
});

/// 某宠物的健康记录流。
final healthRecordsProvider =
    StreamProvider.family<List<HealthRecord>, String>((ref, petId) {
  return ref.watch(healthRepoProvider).watchByPet(petId);
});

/// 当前宠物的健康记录。
final currentPetRecordsProvider = Provider<List<HealthRecord>>((ref) {
  final pet = ref.watch(currentPetProvider);
  if (pet == null) return const <HealthRecord>[];
  return ref.watch(healthRecordsProvider(pet.id)).valueOrNull ??
      const <HealthRecord>[];
});

/// 全部宠物的时刻（时间线页）。
final allMomentsProvider = StreamProvider<List<Moment>>((ref) {
  return ref.watch(momentRepoProvider).watchAll();
});

/// 某宠物的时刻。
final momentsProvider = StreamProvider.family<List<Moment>, String>(
    (ref, petId) {
  return ref.watch(momentRepoProvider).watchByPet(petId);
});

/// 全部消费。
final expensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepoProvider).watchAll();
});

/// 当前宠物的饮食偏好。
final dietProfileProvider =
    StreamProvider.family<DietProfile?, String>((ref, petId) {
  return ref.watch(dietRepoProvider).watchProfile(petId);
});

// ---------- AI ----------

final aiConfigProvider = StateNotifierProvider<AiConfigNotifier, AiConfig>(
    (ref) => AiConfigNotifier(ref.read(settingsRepoProvider)));

class AiConfigNotifier extends StateNotifier<AiConfig> {
  AiConfigNotifier(this._repo) : super(AiConfig()) {
    _load();
  }

  final SettingsRepository _repo;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static const String _keyApiKey = 'chongji.ai.apiKey';

  Future<void> _load() async {
    final json = await _repo.getJson(SettingsRepository.keyAiConfig);
    var config = json == null ? AiConfig() : AiConfig.fromJson(json);

    // 密钥只在安全存储（钥匙串/Keystore），设置表不落明文。
    var key = await _secure.read(key: _keyApiKey);
    if ((key == null || key.isEmpty) && config.apiKey.trim().isNotEmpty) {
      key = config.apiKey;
      await _secure.write(key: _keyApiKey, value: key);
    }
    if (config.apiKey.isNotEmpty) {
      await _repo.setJson(SettingsRepository.keyAiConfig,
          {...config.toJson(), 'apiKey': ''});
    }
    state = AiConfig(
      enabled: config.enabled,
      baseUrl: config.baseUrl,
      apiKey: key ?? '',
      model: config.model,
      temperature: config.temperature,
    );
  }

  Future<void> save(AiConfig config) async {
    state = config;
    await _secure.write(key: _keyApiKey, value: config.apiKey);
    await _repo.setJson(SettingsRepository.keyAiConfig,
        {...config.toJson(), 'apiKey': ''});
  }
}

final aiClientProvider = Provider<AiClient>((ref) {
  final config = ref.watch(aiConfigProvider);
  return AiClient(config);
});

final aiServiceProvider = Provider<AiService>(
    (ref) => AiService(ref.read(aiClientProvider)));

// ---------- 其他 ----------

/// 上次备份时间。
final lastBackupAtProvider = FutureProvider<DateTime?>((ref) async {
  final v = await ref
      .watch(settingsRepoProvider)
      .get(SettingsRepository.keyLastBackupAt);
  return v == null ? null : DateTime.tryParse(v);
});
