import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../domain/services/health_calculator.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 首页：宠物大图横幅（下拉切换）+ 今日概览 + 到期倒计时 + 最近时刻。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];

    if (pets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('宠迹')),
        body: EmptyView(
          icon: Icons.pets,
          title: '还没有宠物档案',
          subtitle: '添加第一只宠物，开始记录它的健康与日常',
          action: FilledButton(
            onPressed: () => context.push('/pet/new'),
            child: const Text('添加宠物'),
          ),
        ),
      );
    }

    final pet = ref.watch(currentPetProvider) ?? pets.first;
    final records = ref.watch(currentPetRecordsProvider);
    final moments = ref.watch(allMomentsProvider).valueOrNull ?? const [];
    final petMoments = moments.where((m) => m.petId == pet.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final dues = buildDueItems(pet, records);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ai/chat'),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('AI 助手'),
        tooltip: 'AI 助手',
      ),
      body: CustomScrollView(
        slivers: [
          _PetBanner(pet: pet, pets: pets),
          SliverPadding(
            padding: const EdgeInsets.only(top: 14, bottom: 24),
            sliver: SliverList.list(
              children: [
                // 到期提醒。
                SectionTitle(
                  '到期提醒',
                  trailing: dues.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => context.push('/health'),
                          child: const Text('健康页'),
                        ),
                ),
                if (dues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_outlined,
                                color: AppTheme.okGreen, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('近期没有疫苗 / 驱虫 / 生日到期，一切都在计划中',
                                  style: AppTheme.subhead(
                                      Theme.of(context).colorScheme.onSurface)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...dues.take(3).map((due) => _DueCard(due: due)),
                // AI 综合判断。
                SectionTitle('AI 洞察'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _InsightCard(pet: pet, records: records),
                ),
                // 最近时刻。
                SectionTitle(
                  '最近时刻',
                  trailing: TextButton(
                    onPressed: () => context.go('/timeline'),
                    child: const Text('时间线'),
                  ),
                ),
                if (petMoments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('记录游玩、美容、生日这些值得纪念的日子',
                            style: AppTheme.subhead(
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    ),
                  )
                else
                  ...petMoments.take(3).map((m) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            onTap: () => context.go('/timeline'),
                            leading: m.imagePaths.isEmpty
                                ? Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: momentTypeColor(m.type)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.photo_outlined,
                                        color: momentTypeColor(m.type)),
                                  )
                                : LocalImage(
                                    m.imagePaths.first,
                                    size: 52,
                                    borderRadius: 10,
                                  ),
                            title: Text(m.title,
                                style: AppTheme.cardTitle(
                                    Theme.of(context).colorScheme.onSurface)),
                            subtitle: Text(
                              '${m.type.label} · ${m.date.month}/${m.date.day}',
                              style: AppTheme.footnote(
                                  Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部宠物横幅：大图铺满 + 渐变 + 宠物名/信息 + 下拉切换。
class _PetBanner extends StatelessWidget {
  const _PetBanner({required this.pet, required this.pets});

  final Pet pet;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = ImageStore.exists(pet.avatarPath);
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 210,
      pinned: false,
      stretch: true,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      actions: [
        // 同步 / 设置 收进横幅右上角；AI 助手在右下角悬浮球。
        const SyncButtonLight(),
        IconButton(
          icon: Icon(Icons.settings_outlined,
              color: hasPhoto ? Colors.white : cs.onSurfaceVariant,
              shadows: hasPhoto ? _shadow : null),
          tooltip: '设置',
          onPressed: () => context.push('/settings'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onTap: () => context.push('/pet/${pet.id}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 大图（无图时用主题色占位）。
              if (hasPhoto)
                Image.file(
                  File(pet.avatarPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(cs),
                )
              else
                _placeholder(cs),
              // 底部渐变保证文字可读。
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              // 宠物名 + 信息 + 下拉切换。
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pet.name,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              shadows: _shadow,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${pet.species.label} · ${pet.breedLabel} · ${HealthCalculator.ageText(pet.birthday)}'
                            '${pet.gender == PetGender.unknown ? "" : " · ${pet.gender.label}"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.92),
                              shadows: _shadow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PetDropdown(pet: pet, pets: pets),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _shadow = <Shadow>[
    Shadow(blurRadius: 6, color: Colors.black54),
  ];

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.primary.withValues(alpha: 0.9),
        child: const Icon(Icons.pets, color: Colors.white24, size: 96),
      );
}

/// 宠物下拉切换（PopupMenu，半透明深色底白字）。
class _PetDropdown extends StatelessWidget {
  const _PetDropdown({required this.pet, required this.pets});

  final Pet pet;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: PopupMenuButton<String>(
        tooltip: '切换宠物',
        color: const Color(0xF5202C33),
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (id) {
          if (id == '__add__') {
            context.push('/pet/new');
          } else {
            ProviderScope.containerOf(context)
                .read(currentPetIdProvider.notifier)
                .select(id);
          }
        },
        itemBuilder: (context) => [
          for (final p in pets)
            PopupMenuItem(
              value: p.id,
              child: Row(
                children: [
                  PetAvatar(
                    path: p.avatarPath,
                    speciesIcon:
                        p.species == PetSpecies.cat ? Icons.pets : Icons.pets,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: p.id == pet.id ? FontWeight.w700 : FontWeight.w400,
                      color: p.id == pet.id
                          ? const Color(0xFF25D366)
                          : Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (p.id == pet.id)
                    const Icon(Icons.check_rounded,
                        color: Color(0xFF25D366), size: 18),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: '__add__',
            child: Row(
              children: [
                Icon(Icons.add, color: Color(0xFF25D366), size: 20),
                SizedBox(width: 10),
                Text('添加宠物',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PetAvatar(
                path: pet.avatarPath,
                speciesIcon:
                    pet.species == PetSpecies.cat ? Icons.pets : Icons.pets,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text('切换',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600)),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// 到期提醒卡：按类型配色（生日/纪念日喜庆，疫苗/驱虫重要）+ 紧急度徽章。
class _DueCard extends StatelessWidget {
  const _DueCard({required this.due});

  final DueItem due;

  static const _kindMeta = <String, (Color, IconData)>{
    // 喜庆：生日亮粉、到家纪念日亮橙。
    'birthday': (Color(0xFFEC4899), Icons.cake_rounded),
    'adoption': (Color(0xFFF97316), Icons.home_rounded),
    // 重要：疫苗亮蓝、驱虫亮紫。
    'vaccine': (Color(0xFF3B82F6), Icons.vaccines_rounded),
    'dewormIn': (Color(0xFF8B5CF6), Icons.shield_rounded),
    'dewormOut': (Color(0xFF8B5CF6), Icons.shield_outlined),
    // 测量：称重蓝、体型琥珀。
    'weight': (Color(0xFF3B82F6), Icons.monitor_weight_rounded),
    'bcs': (Color(0xFFF59E0B), Icons.accessibility_new_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (kindColor, icon) =
        _kindMeta[due.kind] ?? (cs.primary, Icons.schedule_rounded);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: kindColor, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kindColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: kindColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(due.title,
                          style: AppTheme.cardTitle(cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        '${due.date.month}月${due.date.day}日 到期',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kindColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                DueBadge(daysLeft: due.daysLeft, tone: kindColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 首页 AI 综合判断卡：近期到期 + 体重体型 + 近 14 天事件 → 意见建议。
class _InsightCard extends ConsumerStatefulWidget {
  const _InsightCard({required this.pet, required this.records});

  final Pet pet;
  final List<HealthRecord> records;

  @override
  ConsumerState<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<_InsightCard> {
  static const _cacheKey = 'homeInsight';
  String? _text;
  DateTime? _at;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void didUpdateWidget(covariant _InsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换宠物后旧洞察立刻失效，避免显示别的宠物的结论。
    if (oldWidget.pet.id != widget.pet.id) {
      _text = null;
      _at = null;
      _error = null;
      _loadCache();
    }
  }

  Future<void> _loadCache() async {
    final json = await ref.read(settingsRepoProvider).getJson(_cacheKey);
    if (json == null || !mounted) return;
    // 只显示当前宠物的缓存。
    if (json['petId'] != widget.pet.id) return;
    setState(() {
      _text = json['text'] as String?;
      _at =
          json['at'] == null ? null : DateTime.tryParse(json['at'] as String);
    });
  }

  Future<void> _saveCache(String text) async {
    await ref.read(settingsRepoProvider).setJson(_cacheKey, {
      'text': text,
      'at': DateTime.now().toIso8601String(),
      'petId': widget.pet.id,
    });
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dues = buildDueItems(widget.pet, widget.records);
      final text = await ref
          .read(aiServiceProvider)
          .homeInsight(widget.pet, widget.records, dues);
      await _saveCache(text);
      if (mounted) {
        setState(() {
          _text = text;
          _at = DateTime.now();
        });
      }
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final aiReady = ref.watch(aiConfigProvider).isReady;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('近期综合判断',
                      style: AppTheme.cardTitle(cs.onSurface)),
                ),
                if (_at != null && !_loading)
                  Text(
                    _at!.month == DateTime.now().month &&
                            _at!.day == DateTime.now().day
                        ? '今天更新'
                        : '${_at!.month}/${_at!.day} 更新',
                    style: AppTheme.captionSm(cs.onSurfaceVariant),
                  ),
                const SizedBox(width: 6),
                _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _text == null ? Icons.play_arrow_rounded : Icons.refresh_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                        tooltip: _text == null ? '生成' : '刷新',
                        onPressed: aiReady ? _generate : null,
                      ),
              ],
            ),
            const SizedBox(height: 8),
            if (!aiReady)
              Row(
                children: [
                  Expanded(
                    child: Text('配置 AI 后，会根据近期到期、体重与症状给出综合建议',
                        style: AppTheme.subhead(cs.onSurfaceVariant)),
                  ),
                  TextButton(
                    onPressed: () => context.push('/settings/ai'),
                    child: const Text('去配置'),
                  ),
                ],
              )
            else if (_loading && _text == null)
              Row(
                children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('AI 正在分析近期情况…',
                      style: AppTheme.subhead(cs.onSurfaceVariant)),
                ],
              )
            else if (_error != null && _text == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: AppTheme.footnote(AppTheme.warnRed)),
                  TextButton(onPressed: _generate, child: const Text('重试')),
                ],
              )
            else if (_text != null)
              MarkdownBody(
                data: _text!,
                styleSheet: digestMarkdownStyle(context),
                selectable: true,
              )
            else
              Text('点击右侧按钮，让 AI 结合近期情况给出判断与建议',
                  style: AppTheme.subhead(cs.onSurfaceVariant)),
            if (_error != null && _text != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('（刷新失败：$_error）',
                    style: AppTheme.captionSm(AppTheme.warnRed)),
              ),
          ],
        ),
      ),
    );
  }
}
