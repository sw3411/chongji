import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../../domain/services/health_calculator.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 首页：环境光渐变头部 + 宠物胶囊切换 + 渐变场景卡（大数字）+
/// 单色金刚位 + 白瓷片分区（AI 洞察 / 到期提醒 / 横向时刻流）。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (pets.isEmpty) {
      return Scaffold(
        body: _AmbientHeader(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top + 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [SyncButton()],
              ),
              Expanded(
                child: EmptyView(
                  icon: Icons.pets,
                  title: '欢迎来到宠迹',
                  subtitle: '添加第一只宠物，开始记录它的健康与日常',
                  action: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add),
                    label: const Text('添加宠物'),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/pet/new'),
          icon: const Icon(Icons.add),
          label: const Text('添加宠物'),
        ),
      );
    }

    final pet = ref.watch(currentPetProvider) ?? pets.first;
    final records = ref.watch(currentPetRecordsProvider);
    final moments =
        ref.watch(allMomentsProvider).valueOrNull ?? const <Moment>[];
    final petMoments = moments.where((m) => m.petId == pet.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final dues = buildDueItems(pet, records);
    final weight = HealthCalculator.latestWeight(records);
    final bcs = HealthCalculator.latestBcs(records);
    final weightChange = HealthCalculator.weightChange(records, 30);
    final nextDue = dues.isEmpty
        ? null
        : dues.reduce((a, b) => a.daysLeft <= b.daysLeft ? a : b);
    final onPhoto =
        pet.avatarPath != null && ImageStore.exists(pet.avatarPath!);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ai/chat'),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('AI 助手'),
        tooltip: 'AI 助手',
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 顶部照片区 + 悬浮其上的毛玻璃体重卡。
          Stack(
            children: [
              _PhotoHeader(pet: pet, pets: pets, onPhoto: onPhoto),
              Padding(
                padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 150),
                child: _SceneCard(
                  weight: weight?.value,
                  weightDelta: weightChange?.$1,
                  bcs: bcs?.value?.toInt(),
                  nextDue: nextDue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 金刚位（单色）。
          const _QuickActions(),
            // AI 洞察。
            _HomeSection(
              title: 'AI 洞察',
              child: _InsightCard(pet: pet, records: records),
            ),
            // 到期提醒。
            _HomeSection(
              title: '到期提醒',
              trailing: dues.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () => context.go('/health'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('全部',
                            style: AppTheme.footnote(
                                dark ? Colors.white54 : AppTheme.inkSecondary)),
                      ),
                    ),
              child: dues.isEmpty
                  ? _MiniCard(
                      icon: Icons.verified_rounded,
                      text: '近期没有疫苗 / 驱虫 / 生日到期，一切都在计划中',
                    )
                  : _DueGroup(dues: dues.take(3).toList()),
            ),
            // 最近时刻。
            if (petMoments.isNotEmpty)
              _HomeSection(
                title: '最近时刻',
                trailing: GestureDetector(
                  onTap: () => context.go('/timeline'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('全部',
                        style: AppTheme.footnote(
                            dark ? Colors.white54 : AppTheme.inkSecondary)),
                  ),
                ),
                child: SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: petMoments.take(10).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _MomentCard(moment: petMoments[index]),
                  ),
                ),
              ),
            const SizedBox(height: 96),
          ],
        ),
      );
  }
}

/// 顶部照片头：宠物照片铺底 + 暗纱渐入画布，顶栏与问候语坐其上。
class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.pet,
    required this.pets,
    required this.onPhoto,
  });

  final Pet pet;
  final List<Pet> pets;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas = dark ? AppTheme.darkBg : AppTheme.lightBg;
    final height = MediaQuery.paddingOf(context).top + 212;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (onPhoto)
            Image.file(
              File(pet.avatarPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? AppTheme.headerGradientDark
                        : AppTheme.headerGradientLight,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          // 暗纱：顶部压暗保可读，底部渐入画布色消融。
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: onPhoto
                    ? [
                        Colors.black.withValues(alpha: 0.42),
                        Colors.black.withValues(alpha: 0.08),
                        canvas.withValues(alpha: 0.0),
                        canvas,
                      ]
                    : [
                        dark
                            ? AppTheme.headerGradientDark[0]
                            : AppTheme.headerGradientLight[0],
                        canvas,
                      ],
                stops: onPhoto ? const [0, 0.55, 0.8, 1] : const [0, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // 顶栏 + 问候语。
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top + 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: _PetCapsule(pet: pet, pets: pets, onPhoto: onPhoto)),
                    if (onPhoto) const SyncButtonLight() else const SyncButton(),
                    IconButton(
                      icon: Icon(Icons.settings_outlined,
                          color: onPhoto
                              ? Colors.white
                              : (dark ? Colors.white : AppTheme.ink)),
                      tooltip: '设置',
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _Greeting(pet: pet, onPhoto: onPhoto),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 环境光头部：极淡暖光渐变过渡进画布。
class _AmbientHeader extends StatelessWidget {
  const _AmbientHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? AppTheme.headerGradientDark
              : AppTheme.headerGradientLight,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.3],
        ),
      ),
      child: child,
    );
  }
}

/// 宠物身份胶囊：照片头上用毛玻璃，画布上用白瓷片。
class _PetCapsule extends StatelessWidget {
  const _PetCapsule({required this.pet, required this.pets, this.onPhoto = false});

  final Pet pet;
  final List<Pet> pets;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PetAvatar(
          path: pet.avatarPath,
          speciesIcon: Icons.pets,
          size: 28,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${pet.name} · ${pet.speciesLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.cardTitle(
                    onPhoto ? Colors.white : cs.onSurface)
                .copyWith(fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 2),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: onPhoto
                ? Colors.white70
                : cs.onSurfaceVariant,
            size: 20),
      ],
    );
    if (!onPhoto) {
      return GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: content,
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final cs = Theme.of(context).colorScheme;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('切换宠物',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final p in pets)
                  ListTile(
                    leading: PetAvatar(path: p.avatarPath, size: 40),
                    title:
                        Text(p.name, style: AppTheme.cardTitle(cs.onSurface)),
                    subtitle: Text('${p.speciesLabel} · ${p.breedLabel}',
                        style: AppTheme.caption(cs.onSurfaceVariant)),
                    trailing: p.id == pet.id
                        ? Icon(Icons.check_rounded,
                            color: cs.primary, size: 22)
                        : null,
                    onTap: () {
                      ref.read(currentPetIdProvider.notifier).select(p.id);
                      Navigator.pop(context);
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: cs.primary),
                  ),
                  title:
                      Text('添加宠物', style: AppTheme.cardTitle(cs.primary)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/pet/new');
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 问候语：时段问候 + 宠物名（照片头上为白色）。
class _Greeting extends StatelessWidget {
  const _Greeting({required this.pet, this.onPhoto = false});

  final Pet pet;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mainColor = onPhoto
        ? Colors.white
        : (dark ? Colors.white : AppTheme.ink);
    final subColor = onPhoto
        ? Colors.white70
        : (dark ? Colors.white38 : AppTheme.inkSecondary);
    final hour = DateTime.now().hour;
    final hello = hour < 6
        ? '夜深了'
        : hour < 11
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$hello，${pet.name}',
          style: AppTheme.largeTitle(mainColor, size: 19),
        ),
        const SizedBox(height: 4),
        Text(
          '${now.month}月${now.day}日 周${weekdays[now.weekday - 1]} · '
          '${HealthCalculator.ageText(pet.birthday)}的${pet.speciesLabel}',
          style: AppTheme.subhead(subColor),
        ),
      ],
    );
  }
}

/// 体重场景卡：陶土渐变底 + 毛玻璃（BackdropFilter 模糊下方照片），
/// 大数字体重 + 体型/下次到期次级信息 + 快捷记录三连。
class _SceneCard extends StatelessWidget {
  const _SceneCard({
    this.weight,
    this.weightDelta,
    this.bcs,
    this.nextDue,
  });

  final double? weight;
  final double? weightDelta;
  final int? bcs;
  final DueItem? nextDue;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onCard = Colors.white.withValues(alpha: 0.95);
    final onCardFaint = Colors.white.withValues(alpha: 0.6);
    // 半透明陶土渐变：叠在照片上时透出模糊底图，形成毛玻璃质感。
    final gradient = LinearGradient(
      colors: dark
          ? [
              AppTheme.sceneGradientDark[0].withValues(alpha: 0.82),
              AppTheme.sceneGradientDark[1].withValues(alpha: 0.94),
            ]
          : [
              AppTheme.sceneGradientLight[0].withValues(alpha: 0.72),
              AppTheme.sceneGradientLight[1].withValues(alpha: 0.92),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 244),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 体重大数字。
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('当前体重',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2,
                                    color: onCardFaint)),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  weight == null
                                      ? '—'
                                      : weight!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -1.5,
                                    height: 1.05,
                                    color: onCard,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('kg',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                        color: onCardFaint)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // 30 天变化胶囊。
                        if (weightDelta != null && weightDelta != 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '30天 ${weightDelta! >= 0 ? "+" : ""}${weightDelta!.toStringAsFixed(2)}kg',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: onCard,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 发丝分隔线。
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    const SizedBox(height: 12),
                    // 体型 + 下次到期（各占半宽，到期文案不再截断）。
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/health/record/new',
                                extra: 'bcs'),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('体型 BCS',
                                    style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        color: onCardFaint)),
                                const SizedBox(height: 3),
                                Text(
                                  bcs == null ? '未评估' : '${bcs!}/9',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w400,
                                    color: onCard,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => context.go('/health'),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('下次到期',
                                    style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        color: onCardFaint)),
                                const SizedBox(height: 4),
                                Text(
                                  nextDue == null
                                      ? '近期无'
                                      : '${nextDue!.title} · ${nextDue!.daysLeft < 0 ? '已过期' : '${nextDue!.daysLeft}天后'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: onCard,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 快捷记录三连。
                    Row(
                      children: [
                        _cardChip(context, Icons.monitor_weight_outlined,
                            '记体重', () => context.push('/health/record/new',
                                extra: 'weight')),
                        const SizedBox(width: 8),
                        _cardChip(context, Icons.vaccines_outlined, '记疫苗',
                            () => context.push('/health/record/new',
                                extra: 'vaccine')),
                        const SizedBox(width: 8),
                        _cardChip(context, Icons.photo_camera_outlined, '记时刻',
                            () => context.push('/moment/new')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  Widget _cardChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 金刚位：白瓷片圆标 + 单色图标（导航保持安静，色彩留给数据）。
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white70 : AppTheme.ink;
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTheme.footnote(dark ? Colors.white60 : AppTheme.ink)
                    .copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          action(Icons.restaurant_outlined, 'AI 饮食', () => context.go('/diet')),
          action(Icons.event_outlined, '日历', () => context.push('/calendar')),
          action(Icons.savings_outlined, '账本', () => context.push('/expenses')),
          action(Icons.auto_awesome_outlined, '周报',
              () => context.push('/ai/weekly')),
        ],
      ),
    );
  }
}

/// 首页分区：小标题 + 内容（统一 16 边距与节律）。
class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      title,
                      style: AppTheme.cardTitle(
                          dark ? Colors.white : AppTheme.ink)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 轻提示小卡（白瓷片）。
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 17,
              color: dark ? Colors.white54 : AppTheme.inkSecondary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  text,
                  style: AppTheme.subhead(
                      dark ? Colors.white60 : AppTheme.ink))),
        ],
      ),
    );
  }
}

/// 横向时刻卡：圆角照片 + 悬浮文字（去盒子感，照片即卡片）。
class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = momentTypeColor(moment.type);
    final hasPhoto = moment.imagePaths.isNotEmpty &&
        ImageStore.exists(moment.imagePaths.first);
    return GestureDetector(
      onTap: () => context.push('/moment/${moment.id}/detail'),
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 88,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withValues(alpha: 0.16),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.file(
                      File(moment.imagePaths.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(color),
                    )
                  : _coverPlaceholder(color),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.footnote(dark ? Colors.white : AppTheme.ink)
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${moment.date.month}/${moment.date.day} · ${moment.type.label}',
                    style: AppTheme.captionSm(
                        dark ? Colors.white38 : AppTheme.inkSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(Color color) => Center(
        child: Icon(Icons.photo_outlined,
            size: 26, color: color.withValues(alpha: 0.6)),
      );
}

/// 到期提醒组：一张白瓷片内多行细分隔线；图标单色，颜色只留给状态徽标。
class _DueGroup extends StatelessWidget {
  const _DueGroup({required this.dues});

  final List<DueItem> dues;

  static const _kindIcon = <String, IconData>{
    'birthday': Icons.cake_rounded,
    'adoption': Icons.home_rounded,
    'vaccine': Icons.vaccines_rounded,
    'dewormIn': Icons.shield_rounded,
    'dewormOut': Icons.shield_outlined,
    'weight': Icons.monitor_weight_rounded,
    'bcs': Icons.accessibility_new_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < dues.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 14,
                  color: dark ? Colors.white.withValues(alpha: 0.06) : AppTheme.lightDivider),
            _dueRow(context, dues[i]),
          ],
        ],
      ),
    );
  }

  Widget _dueRow(BuildContext context, DueItem due) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icon = _kindIcon[due.kind] ?? Icons.schedule_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : AppTheme.lightDivider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 17,
                color: dark ? Colors.white60 : AppTheme.inkSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(due.title,
                    style: AppTheme.cardTitle(
                        dark ? Colors.white : AppTheme.ink)),
                const SizedBox(height: 1),
                Text(
                  '${due.date.month}月${due.date.day}日 到期',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: dark ? Colors.white38 : AppTheme.inkSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          DueBadge(daysLeft: due.daysLeft),
        ],
      ),
    );
  }
}

/// 首页 AI 综合判断卡：白瓷片 + 小强调图标 + Markdown 正文。
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final aiReady = ref.watch(aiConfigProvider).isReady;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 16, color: dark ? Colors.white60 : AppTheme.inkSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('近期综合判断',
                    style: AppTheme.cardTitle(
                        dark ? Colors.white : AppTheme.ink)),
              ),
              if (_at != null && !_loading)
                Text(
                  _at!.month == DateTime.now().month &&
                          _at!.day == DateTime.now().day
                      ? '今天更新'
                      : '${_at!.month}/${_at!.day} 更新',
                  style: AppTheme.captionSm(inkSec),
                ),
              const SizedBox(width: 6),
              _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : GestureDetector(
                      onTap: aiReady ? _generate : null,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _text == null
                              ? Icons.play_arrow_rounded
                              : Icons.refresh_rounded,
                          size: 16,
                          color: AppTheme.green,
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          if (!aiReady)
            Row(
              children: [
                Expanded(
                  child: Text('配置 AI 后，会根据近期到期、体重与症状给出综合建议',
                      style: AppTheme.subhead(inkSec)),
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
                Text('AI 正在分析近期情况…', style: AppTheme.subhead(inkSec)),
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
                style: AppTheme.subhead(inkSec)),
          if (_error != null && _text != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('（刷新失败：$_error）',
                  style: AppTheme.captionSm(AppTheme.warnRed)),
            ),
        ],
      ),
    );
  }
}
