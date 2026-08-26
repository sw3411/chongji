import 'dart:io';

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

/// 首页（出行卡风格）：渐变头部 + 宠物胶囊切换 + 数据大卡 + 金刚位 +
/// AI 洞察 + 到期提醒 + 横向时刻流。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (pets.isEmpty) {
      return Scaffold(
        body: _HeaderGradient(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top + 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [SyncButton()],
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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ai/chat'),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('AI 助手'),
        tooltip: 'AI 助手',
      ),
      body: _HeaderGradient(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top + 10),
            // 顶栏：宠物胶囊 + 同步/设置。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _PetCapsule(pet: pet, pets: pets)),
                  const SyncButton(),
                  IconButton(
                    icon: Icon(Icons.settings_outlined,
                        color: dark ? Colors.white : AppTheme.ink),
                    tooltip: '设置',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            // 问候语。
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: _Greeting(pet: pet),
            ),
            const SizedBox(height: 10),
            // 数据大卡。
            _HeroCard(
              pet: pet,
              weight: weight?.value,
              weightDelta: weightChange?.$1,
              bcs: bcs?.value?.toInt(),
              nextDue: nextDue,
            ),
            const SizedBox(height: 16),
            // 金刚位。
            const _QuickActions(),
            const SizedBox(height: 8),
            // AI 洞察。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InsightCard(pet: pet, records: records),
            ),
            // 到期提醒。
            _HomeSection(
              title: '到期提醒',
              trailing: dues.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => context.go('/health'),
                      child: const Text('全部'),
                    ),
              child: dues.isEmpty
                  ? const _MiniCard(
                      icon: Icons.verified_rounded,
                      color: AppTheme.okGreen,
                      text: '近期没有疫苗 / 驱虫 / 生日到期，一切都在计划中 👌',
                    )
                  : _DueGroup(dues: dues.take(3).toList()),
            ),
            // 最近时刻。
            if (petMoments.isNotEmpty)
              _HomeSection(
                title: '最近时刻',
                trailing: TextButton(
                  onPressed: () => context.go('/timeline'),
                  child: const Text('全部'),
                ),
                child: SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: petMoments.take(10).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _MomentCard(moment: petMoments[index]),
                  ),
                ),
              ),
            const SizedBox(height: 92),
          ],
        ),
      ),
    );
  }
}

/// 头部渐变容器：奶油橙渐变过渡到页面底色。
class _HeaderGradient extends StatelessWidget {
  const _HeaderGradient({required this.child});

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
          stops: const [0, 0.32],
        ),
      ),
      child: child,
    );
  }
}

/// 宠物身份胶囊：头像 + 名字 + 下拉切换（参考滴滴宠物头部）。
class _PetCapsule extends StatelessWidget {
  const _PetCapsule({required this.pet, required this.pets});

  final Pet pet;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: Row(
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
                style:
                    AppTheme.cardTitle(cs.onSurface).copyWith(fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: cs.onSurfaceVariant, size: 20),
          ],
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

/// 问候语：时段问候 + 宠物名。
class _Greeting extends StatelessWidget {
  const _Greeting({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          '$hello，${pet.name} 🐾',
          style: AppTheme.largeTitle(cs.onSurface, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          '${now.month}月${now.day}日 周${weekdays[now.weekday - 1]} · '
          '${HealthCalculator.ageText(pet.birthday)}的${pet.speciesLabel}',
          style: AppTheme.subhead(cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 数据大卡：体重 / 体型 / 下次到期 三栏 + 底部快捷记录按钮。
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.pet,
    this.weight,
    this.weightDelta,
    this.bcs,
    this.nextDue,
  });

  final Pet pet;
  final double? weight;
  final double? weightDelta;
  final int? bcs;
  final DueItem? nextDue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget stat(String label, String value, String? unit, String? sub,
        Color? subColor, Color numberColor, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Text(label, style: AppTheme.label(cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                        style: AppTheme.bigNumber(numberColor, size: 19)),
                    if (unit != null) ...[
                      const SizedBox(width: 2),
                      Text(unit, style: AppTheme.caption(cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 3),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.captionSm(subColor ?? cs.onSurfaceVariant)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 11),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                stat(
                  '当前体重',
                  weight == null ? '—' : weight!.toStringAsFixed(1),
                  weight == null ? null : 'kg',
                  weightDelta == null
                      ? (weight == null ? '去记录' : null)
                      : '30天 ${weightDelta! >= 0 ? "+" : ""}${weightDelta!.toStringAsFixed(2)}',
                  weightDelta == null || weightDelta == 0
                      ? null
                      : weightDelta! > 0
                          ? AppTheme.warnRed
                          : AppTheme.okGreen,
                  weight == null ? cs.onSurface : cs.primary,
                  () => context.push('/health/record/new', extra: 'weight'),
                ),
                _statDivider(cs),
                stat(
                  '体型评分',
                  bcs == null ? '—' : '$bcs',
                  bcs == null ? null : '/9',
                  bcs == null ? '未评估' : null,
                  null,
                  bcs == null ? cs.onSurface : AppTheme.mint,
                  () => context.push('/health/record/new', extra: 'bcs'),
                ),
                _statDivider(cs),
                stat(
                  '下次到期',
                  nextDue == null
                      ? '—'
                      : '${nextDue!.daysLeft < 0 ? 0 : nextDue!.daysLeft}',
                  nextDue == null ? null : '天',
                  nextDue?.title,
                  nextDue == null
                      ? null
                      : nextDue!.daysLeft <= 0
                          ? AppTheme.warnRed
                          : nextDue!.daysLeft <= 7
                              ? AppTheme.warnAmber
                              : AppTheme.okGreen,
                  nextDue == null
                      ? cs.onSurface
                      : nextDue!.daysLeft <= 0
                          ? AppTheme.warnRed
                          : AppTheme.honey,
                  () => context.go('/health'),
                ),
              ],
            ),
            Divider(
                color: cs.outlineVariant.withValues(alpha: 0.6), height: 22),
            Row(
              children: [
                _quickChip(
                    context, Icons.scale_rounded, '记体重', 'weight'),
                const SizedBox(width: 8),
                _quickChip(
                    context, Icons.vaccines_rounded, '疫苗/驱虫', 'vaccine'),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      textStyle: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => context.push('/moment/new'),
                    icon: const Icon(Icons.photo_camera_rounded, size: 17),
                    label: const Text('记时刻'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider(ColorScheme cs) => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: cs.outlineVariant.withValues(alpha: 0.6),
      );

  Widget _quickChip(BuildContext context, IconData icon, String label,
      String type) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 9),
          side: BorderSide(color: cs.outlineVariant),
          foregroundColor: cs.onSurface,
          textStyle: const TextStyle(fontSize: 12.5),
        ),
        onPressed: () => context.push('/health/record/new', extra: type),
        icon: Icon(icon, size: 17, color: cs.primary),
        label: Text(label, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}

/// 金刚位：渐变圆角方块 + 小字。
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, List<Color> colors,
        VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors[0].withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors[0], size: 19),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: AppTheme.footnote(cs.onSurface)
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          action(Icons.restaurant_rounded, 'AI 饮食',
              [AppTheme.green, const Color(0xFFFF7E79)],
              () => context.go('/diet')),
          action(Icons.event_rounded, '日历',
              [AppTheme.mint, const Color(0xFF2E9E6B)],
              () => context.push('/calendar')),
          action(Icons.savings_rounded, '账本',
              [AppTheme.honey, const Color(0xFFF5A83C)],
              () => context.push('/expenses')),
          action(Icons.auto_awesome_rounded, '周报',
              [AppTheme.sakura, const Color(0xFFF27D9C)],
              () => context.push('/ai/weekly')),
        ],
      ),
    );
  }
}

/// 首页分区：标题 + 内容。
class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style:
                          AppTheme.title(cs.onSurface).copyWith(fontSize: 15, letterSpacing: 0.2)),
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

/// 轻提示小卡。
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTheme.subhead(cs.onSurface))),
        ],
      ),
    );
  }
}

/// 横向时刻卡：竖版照片 + 标题。
class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = momentTypeColor(moment.type);
    final hasPhoto = moment.imagePaths.isNotEmpty &&
        ImageStore.exists(moment.imagePaths.first);
    return GestureDetector(
      onTap: () => context.push('/moment/${moment.id}/detail'),
      child: Container(
        width: 108,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.softShadow(const Color(0x0A3D2E26)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 78,
              width: double.infinity,
              child: hasPhoto
                  ? Image.file(
                      File(moment.imagePaths.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(color),
                    )
                  : _coverPlaceholder(color),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.cardTitle(cs.onSurface)
                        .copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${moment.date.month}/${moment.date.day} · ${moment.type.label}',
                    style: AppTheme.captionSm(color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(Color color) => Container(
        color: color.withValues(alpha: 0.14),
        child: Center(
          child: Icon(Icons.photo_outlined,
              size: 26, color: color.withValues(alpha: 0.6)),
        ),
      );
}

/// 到期提醒组：一张卡内多行分区（细分隔线），避免多卡堆叠。
class _DueGroup extends StatelessWidget {
  const _DueGroup({required this.dues});

  final List<DueItem> dues;

  static const _kindMeta = <String, (Color, IconData)>{
    'birthday': (Color(0xFFFF7D9E), Icons.cake_rounded),
    'adoption': (Color(0xFFF5A83C), Icons.home_rounded),
    'vaccine': (Color(0xFF5B9BD5), Icons.vaccines_rounded),
    'dewormIn': (Color(0xFF8B7BD8), Icons.shield_rounded),
    'dewormOut': (Color(0xFF8B7BD8), Icons.shield_outlined),
    'weight': (Color(0xFF5B9BD5), Icons.monitor_weight_rounded),
    'bcs': (Color(0xFFF5A83C), Icons.accessibility_new_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < dues.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 14,
                  color: cs.outlineVariant.withValues(alpha: 0.7)),
            _dueRow(context, dues[i]),
          ],
        ],
      ),
    );
  }

  Widget _dueRow(BuildContext context, DueItem due) {
    final cs = Theme.of(context).colorScheme;
    final (kindColor, icon) =
        _kindMeta[due.kind] ?? (cs.primary, Icons.schedule_rounded);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kindColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: kindColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(due.title, style: AppTheme.cardTitle(cs.onSurface)),
                const SizedBox(height: 1),
                Text(
                  '${due.date.month}月${due.date.day}日 到期',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          DueBadge(daysLeft: due.daysLeft, tone: kindColor),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final aiReady = ref.watch(aiConfigProvider).isReady;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.07),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: AppTheme.primaryGradient),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('AI 近期综合判断',
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
                        _text == null
                            ? Icons.play_arrow_rounded
                            : Icons.refresh_rounded,
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
    );
  }
}
