import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/constants/app_info.dart';
import 'core/notifications/notification_service.dart';
import 'data/db/app_database.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/health_record_repository.dart';
import 'data/repositories/moment_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final container =
      ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
  unawaited(_startupTasks(container, db));
  runApp(UncontrolledProviderScope(
    container: container,
    child: const ChongjiApp(),
  ));
}

/// 启动任务：清理过期墓碑 + 静默拉取全部云空间（失败不打扰）。
Future<void> _startupTasks(ProviderContainer container, AppDatabase db) async {
  try {
    await HealthRecordRepository(db).purge(365);
    await MomentRepository(db).purge(365);
    await ExpenseRepository(db).purge(365);
  } catch (_) {}
  try {
    // 提醒默认开启：若系统权限未授予（从未弹过授权框），启动时申请一次。
    final settings = container.read(appSettingsProvider);
    if (settings.reminderEnabled &&
        !await NotificationService.isPermissionGranted()) {
      await NotificationService.requestPermission();
    }
    await rescheduleDailyDigest(container.read);
  } catch (_) {}
  try {
    final spaces = await container.read(cloudSpaceRepoProvider).getAll();
    final sync = container.read(spaceSyncProvider);
    for (final s in spaces) {
      try {
        // 拉取最新；若离线期间本机有修改且可写，一并推送。
        await sync.sync(s);
      } catch (_) {}
    }
  } catch (_) {}
}

class ChongjiApp extends ConsumerWidget {
  const ChongjiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appSettingsProvider).themeMode;
    return MaterialApp.router(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
