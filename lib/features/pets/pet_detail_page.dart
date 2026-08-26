import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/notifications/notification_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../domain/services/health_calculator.dart';
import '../../shared/widgets/common.dart';

/// 宠物详情：档案总览 + 各模块入口。
class PetDetailPage extends ConsumerWidget {
  const PetDetailPage(this.petId, {super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    Pet? pet;
    for (final p in pets) {
      if (p.id == petId) pet = p;
    }
    if (pet == null) {
      return Scaffold(body: loadingView);
    }
    final p0 = pet; // 闭包内无法依赖外层的空提升，落到不可空局部变量。
    final records = ref.watch(healthRecordsProvider(p0.id)).valueOrNull ??
        const <HealthRecord>[];
    final cs = Theme.of(context).colorScheme;
    final weight = HealthCalculator.latestWeight(records);
    final bcs = HealthCalculator.latestBcs(records);

    return Scaffold(
      appBar: AppBar(
        title: Text(p0.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑档案',
            onPressed: () => context.push('/pet/${p0.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, ref, v, p0),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'switch', child: Text('设为当前宠物')),
              PopupMenuItem(value: 'delete', child: Text('删除宠物')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              PetAvatar(
                path: p0.avatarPath,
                speciesIcon:
                    p0.species == PetSpecies.cat ? Icons.pets : Icons.pets,
                size: 84,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p0.name, style: AppTheme.title(cs.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      '${p0.species.label} · ${p0.breedLabel} · ${HealthCalculator.ageText(p0.birthday)}',
                      style: AppTheme.subhead(cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p0.gender.label}${p0.neutered ? " · 已绝育" : ""}',
                      style: AppTheme.caption(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: '当前体重',
                  value: weight == null ? '—' : '${weight.value}',
                  subValue: weight == null ? '去健康页记录' : 'kg · ${weight.date.month}/${weight.date.day}',
                  onTap: () => context.push('/health'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricTile(
                  label: '体型评分',
                  value: bcs == null ? '—' : '${bcs.value!.toInt()}/9',
                  subValue: bcs == null ? '未评估' : 'BCS',
                  onTap: () => context.push('/health'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow('生日', p0.birthday == null
                      ? null
                      : '${p0.birthday!.year}年${p0.birthday!.month}月${p0.birthday!.day}日'),
                  InfoRow('到家日期', p0.adoptionDate == null
                      ? null
                      : '${p0.adoptionDate!.year}年${p0.adoptionDate!.month}月${p0.adoptionDate!.day}日'),
                  InfoRow('备注', p0.notes),
                ],
              ),
            ),
          ),
          const SectionTitle('记录'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text('健康记录',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text('体重 / 疫苗 / 驱虫 / 就诊',
                      style: AppTheme.footnote(cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(currentPetIdProvider.notifier).select(petId);
                    context.push('/health');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restaurant_outlined),
                  title: Text('饮食与喂食计划',
                      style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text('偏好设置 + AI 计划',
                      style: AppTheme.footnote(cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(currentPetIdProvider.notifier).select(petId);
                    context.push('/diet');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_back_outlined),
                  title:
                      Text('时刻', style: AppTheme.cardTitle(cs.onSurface)),
                  subtitle: Text('照片时间线',
                      style: AppTheme.footnote(cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/timeline'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _onMenu(
      BuildContext context, WidgetRef ref, String action, Pet pet) async {
    switch (action) {
      case 'switch':
        ref.read(currentPetIdProvider.notifier).select(pet.id);
        if (context.mounted) showAutoToast(context, '已切换到 ${pet.name}');
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除 ${pet.name}？'),
            content: const Text('将删除它的全部健康记录、时刻、喂食计划；消费记录会保留（标记为无归属）。此操作不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.warnRed),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await NotificationService.cancelPet(pet.id);
          await ref.read(petRepoProvider).hardDelete(pet.id);
          if (context.mounted) {
            showAutoToast(context, '已删除');
            context.go('/home');
          }
        }
        break;
    }
  }
}
