import 'dart:io' as io;
import 'dart:ui' as ui;

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
    final wVal = weight?.value;
    final wDelta = weightChange?.$1;
    final bVal = bcs?.value?.toInt();
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
          // 照片英雄区：白字核心信息坐照片上，下方接全局深底信息流。
          _HeroSection(
            pet: pet,
            pets: pets,
          ),
          // 核心信息：体重 / 体型 / 下次到期，白字直接坐深底画布。
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前体重',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.62)
                            : AppTheme.inkSecondary)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      wVal == null ? '—' : wVal.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2,
                        height: 1.05,
                        color: dark ? Colors.white : AppTheme.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('kg',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: dark
                                ? Colors.white.withValues(alpha: 0.72)
                                : AppTheme.inkSecondary)),
                    const Spacer(),
                    if (wDelta != null && wDelta != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppTheme.ink.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '30天 ${wDelta >= 0 ? "+" : ""}${wDelta.toStringAsFixed(2)}kg',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: dark
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppTheme.ink,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                    height: 1,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.10)
                        : AppTheme.lightDivider),
                const SizedBox(height: 16),
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
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: dark
                                        ? Colors.white
                                            .withValues(alpha: 0.58)
                                        : AppTheme.inkTertiary)),
                            const SizedBox(height: 6),
                            Text(
                              bVal == null ? '未评估' : '$bVal/9',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: dark ? Colors.white : AppTheme.ink,
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
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppTheme.lightDivider,
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
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: dark
                                        ? Colors.white
                                            .withValues(alpha: 0.58)
                                        : AppTheme.inkTertiary)),
                            const SizedBox(height: 6),
                            Text(
                              nextDue == null
                                  ? '近期无'
                                  : '${nextDue.title} · ${nextDue.daysLeft < 0 ? '已过期' : '${nextDue.daysLeft}天后'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                                color: dark
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : AppTheme.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 近期关注（AI 判断）。
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: _InsightCard(pet: pet, records: records),
          ),
            // 到期提醒。
            _HomeSection(
              title: '到期提醒 ⏰',
              trailing: dues.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () => context.go('/health'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('全部',
                            style: AppTheme.footnote(Colors.white54)),
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
                title: '最近时刻 📸',
                trailing: GestureDetector(
                  onTap: () => context.go('/timeline'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('全部',
                        style: AppTheme.footnote(Colors.white54)),
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

/// 照片英雄区：照片 fitWidth 自然比例完整显示（绝不放大），顶部是宠物
/// 身份与问候；当前体重与体型 BCS 以高亮白字直接坐在照片底缘
/// （底部仅一层暗化渐变保证可读）。照片下方即全局深底信息流。
class _HeroSection extends StatefulWidget {
  const _HeroSection({
    required this.pet,
    required this.pets,
  });

  final Pet pet;
  final List<Pet> pets;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  /// 照片宽高比缓存（path → height/width）。
  static final _aspectCache = <String, double>{};
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _loadAspect();
  }

  @override
  void didUpdateWidget(covariant _HeroSection old) {
    super.didUpdateWidget(old);
    if (old.pet.avatarPath != widget.pet.avatarPath) {
      _aspect = null;
      _loadAspect();
    }
  }

  Future<void> _loadAspect() async {
    final path = widget.pet.avatarPath;
    if (path == null) return;
    final cached = _aspectCache[path];
    if (cached != null) {
      if (mounted) setState(() => _aspect = cached);
      return;
    }
    try {
      final bytes = await io.File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      _aspectCache[path] = image.height / image.width;
      image.dispose();
      if (mounted && widget.pet.avatarPath == path) {
        setState(() => _aspect = _aspectCache[path]);
      }
    } catch (_) {
      // 解码失败时用默认比例。
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusTop = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;
    final pet = widget.pet;
    final hasAvatar =
        pet.avatarPath != null && ImageStore.exists(pet.avatarPath!);
    final fallback = LinearGradient(
      colors:
          dark ? AppTheme.sceneGradientDark : AppTheme.sceneGradientLight,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // 照片自然高度：宽 × 高宽比（完整显示，极长竖图才封顶）；未解码前先估值。
    final photoH = hasAvatar && _aspect != null
        ? (screenW * _aspect!).clamp(120.0, screenH * 0.62)
        : screenH * 0.42;
    return SizedBox(
      height: photoH,
      child: Stack(
        children: [
          // ---- 清晰照片：完整显示，fitWidth 顶部对齐（绝不放大）----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: photoH,
            child: hasAvatar
                ? Image.file(
                    io.File(pet.avatarPath!),
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(gradient: fallback),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(gradient: fallback)),
          ),
          // ---- 暗纱：顶部连续渐变（顶栏/问候可读）----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenH * 0.4,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x6B000000),
                      Color(0x1F000000),
                      Color(0x00000000),
                    ],
                    stops: [0, 0.5, 1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          // ---- 内容：身份 + 问候（上）/ 大留白 ----
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: statusTop + 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _PetTitle(pet: pet, pets: widget.pets)),
                      const SyncButtonLight(),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined,
                            color: Colors.white),
                        tooltip: '设置',
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: _Greeting(pet: pet, onPhoto: true),
                ),
              ],
            ),
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

/// 宠物标题：头像 + 名字 + 下拉箭头（与健康页标题同语言，无外框），
/// 点击弹出宠物切换面板。
class _PetTitle extends StatelessWidget {
  const _PetTitle({required this.pet, required this.pets});

  final Pet pet;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PetAvatar(
            path: pet.avatarPath,
            speciesIcon: Icons.pets,
            size: 32,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.largeTitle(Colors.white, size: 19),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.7), size: 22),
        ],
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
    final species = switch (pet.speciesLabel) {
      '狗' => '狗狗',
      '猫' => '猫咪',
      _ => pet.speciesLabel,
    };
    final speciesEmoji = switch (pet.speciesLabel) {
      '狗' => ' 🐶',
      '猫' => ' 🐱',
      _ => ' 🐾',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hello,
          style: AppTheme.largeTitle(mainColor, size: 19),
        ),
        const SizedBox(height: 4),
        Text(
          '${now.month}月${now.day}日 周${weekdays[now.weekday - 1]} · '
          '${HealthCalculator.ageText(pet.birthday)}的$species$speciesEmoji',
          style: AppTheme.subhead(subColor),
        ),
      ],
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
        color: dark ? Colors.white.withValues(alpha: 0.04) : AppTheme.lightSurface,
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
                      io.File(moment.imagePaths.first),
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

  static const _kindEmoji = <String, String>{
    'birthday': '🎂',
    'adoption': '🏠',
    'vaccine': '💉',
    'dewormIn': '🛡️',
    'dewormOut': '🛡️',
    'weight': '⚖️',
    'bcs': '🐾',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : AppTheme.lightSurface,
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
    final emoji = _kindEmoji[due.kind] ?? '⏰';
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
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 15, height: 1)),
            ),
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

    // 无卡片容器：内容直接嵌入画布（与英雄区数据区同语言）。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            Row(
              children: [
                Expanded(
                  child: Text('让 AI 结合近期情况给出判断与建议',
                      style: AppTheme.subhead(inkSec)),
                ),
                GestureDetector(
                  onTap: _generate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Text('生成',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.green)),
                  ),
                ),
              ],
            ),
          if (_text != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _at!.month == DateTime.now().month &&
                          _at!.day == DateTime.now().day
                      ? '今天更新'
                      : '${_at!.month}/${_at!.day} 更新',
                  style: AppTheme.captionSm(inkSec),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  GestureDetector(
                    onTap: aiReady ? _generate : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh_rounded,
                              size: 13, color: AppTheme.green),
                          const SizedBox(width: 4),
                          Text('更新',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.green)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
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
