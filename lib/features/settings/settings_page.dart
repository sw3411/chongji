import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/notifications/notification_service.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// 设置主页：宠物管理 / 提醒 / AI / 备份 / 外观 / 关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final currentPet = ref.watch(currentPetProvider);
    final aiReady = ref.watch(aiConfigProvider).isReady;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('宠物'),
          Card(
            child: Column(
              children: [
                for (final p in pets)
                  ListTile(
                    leading: const Icon(Icons.pets_outlined),
                    title:
                        Text(p.name, style: AppTheme.cardTitle(cs.onSurface)),
                    subtitle: Text('${p.species.label} · ${p.breedLabel}',
                        style: AppTheme.footnote(cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pet/${p.id}'),
                  ),
                if (currentPet != null)
                  ListTile(
                    leading: const Icon(PhosphorIconsDuotone.images),
                    title: Text('首页轮播图',
                        style: AppTheme.cardTitle(cs.onSurface)),
                    subtitle: Text('顶图自动轮播 · 每 8 秒一张',
                        style: AppTheme.footnote(cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context
                        .push('/settings/carousel', extra: currentPet),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('添加宠物',
                      style: AppTheme.cardTitle(cs.primary)),
                  onTap: () => context.push('/pet/new'),
                ),
              ],
            ),
          ),
          const SectionTitle('AI'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text('AI 助手设置',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text(aiReady ? '已配置' : '未配置',
                      style: AppTheme.footnote(
                          aiReady ? AppTheme.okGreen : cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/ai'),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: Text('AI 对话',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ai/chat'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text('健康周报',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ai/weekly'),
                ),
              ],
            ),
          ),
          const SectionTitle('提醒'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: Text('到期提醒',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text('疫苗 / 驱虫 / 称重 / 体型 / 生日',
                      style: AppTheme.footnote(cs.onSurfaceVariant)),
                  value: settings.reminderEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final granted = await NotificationService.requestPermission();
                      if (!granted) {
                        if (context.mounted) {
                          showAutoToast(context, '请在系统设置中允许通知权限');
                        }
                        return;
                      }
                    } else {
                      await NotificationService.cancelAll();
                    }
                    await ref
                        .read(appSettingsProvider.notifier)
                        .update(settings.copy()..reminderEnabled = v);
                    if (v && context.mounted) _rescheduleAll(ref);
                  },
                ),
                if (settings.reminderEnabled) ...[
                  SwitchListTile(
                    secondary: const Icon(PhosphorIconsDuotone.sun),
                    title: Text('每日提醒摘要',
                        style: AppTheme.cardTitle(cs.onSurface)),
                    subtitle: Text(
                        '每天 ${settings.dailyDigestHour}:00 推送当日到期事项',
                        style: AppTheme.footnote(cs.onSurfaceVariant)),
                    value: settings.dailyDigestEnabled,
                    onChanged: (v) async {
                      if (v &&
                          !await NotificationService.isPermissionGranted()) {
                        final granted =
                            await NotificationService.requestPermission();
                        if (!granted) {
                          if (context.mounted) {
                            showAutoToast(context, '请在系统设置中允许通知权限');
                          }
                          return;
                        }
                      }
                      await ref.read(appSettingsProvider.notifier).update(
                          settings.copy()..dailyDigestEnabled = v);
                      await rescheduleDailyDigest(ref.read);
                    },
                  ),
                  if (settings.dailyDigestEnabled)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      title: Text('推送时间',
                          style: AppTheme.subhead(cs.onSurface)),
                      trailing: Text('${settings.dailyDigestHour.toString().padLeft(2, '0')}:00',
                          style: AppTheme.cardTitle(cs.primary)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              TimeOfDay(hour: settings.dailyDigestHour, minute: 0),
                        );
                        if (picked == null) return;
                        await ref.read(appSettingsProvider.notifier).update(
                            settings.copy()..dailyDigestHour = picked.hour);
                        await rescheduleDailyDigest(ref.read);
                      },
                    ),
                ],
                if (settings.reminderEnabled)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('提前提醒', style: AppTheme.subhead(cs.onSurface)),
                    trailing: DropdownButton<int>(
                      value: settings.reminderDaysBefore,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('提前1天')),
                        DropdownMenuItem(value: 3, child: Text('提前3天')),
                        DropdownMenuItem(value: 7, child: Text('提前7天')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref.read(appSettingsProvider.notifier).update(
                            settings.copy()..reminderDaysBefore = v);
                        if (context.mounted) _rescheduleAll(ref);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('外观'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text('深色模式', style: AppTheme.cardTitle(cs.onSurface)),
              trailing: SegmentedButton<ThemeModeEntry>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeModeEntry.system, label: Text('跟随')),
                  ButtonSegment(value: ThemeModeEntry.light, label: Text('浅色')),
                  ButtonSegment(value: ThemeModeEntry.dark, label: Text('深色')),
                ],
                selected: {settings.themeMode.entry},
                onSelectionChanged: (s) => ref
                    .read(appSettingsProvider.notifier)
                    .update(settings.copy()
                      ..themeMode = s.first.mode),
              ),
            ),
          ),
          const SectionTitle('数据'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text('消费账本',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text('主粮零食医疗…笔笔清楚',
                      style: AppTheme.footnote(cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/expenses'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text('云空间（多设备共享）',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text('按宠物共享给家人，查看/编辑/管理',
                      style: AppTheme.footnote(cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/cloud'),
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text('备份与恢复',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/backup'),
                ),
              ],
            ),
          ),
          const SectionTitle('关于'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('关于宠迹', style: AppTheme.cardTitle(cs.onSurface)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/about'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 按当前设置重排全部宠物提醒。
  static Future<void> _rescheduleAll(WidgetRef ref) async {
    final pets = await ref.read(petRepoProvider).getAll();
    final settings = ref.read(appSettingsProvider);
    for (final pet in pets.where((p) => !p.isDeleted)) {
      final records = await ref.read(healthRepoProvider).getByPet(pet.id);
      await NotificationService.syncPetReminders(
        pet,
        records,
        enabled: settings.reminderEnabled,
        daysBefore: settings.reminderDaysBefore,
      );
    }
    await rescheduleDailyDigest(ref.read);
  }
}

/// SegmentedButton 泛型不能直接用 ThemeMode（值类型限制），做个桥接枚举。
enum ThemeModeEntry {
  system(ThemeMode.system),
  light(ThemeMode.light),
  dark(ThemeMode.dark);

  const ThemeModeEntry(this.mode);
  final ThemeMode mode;
}

extension ThemeModeEntryX on ThemeMode {
  ThemeModeEntry get entry => switch (this) {
        ThemeMode.system => ThemeModeEntry.system,
        ThemeMode.light => ThemeModeEntry.light,
        ThemeMode.dark => ThemeModeEntry.dark,
      };
}
