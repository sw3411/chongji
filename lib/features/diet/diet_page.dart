import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../core/constants/breeds.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/meal_plan.dart';
import '../../domain/models/pet.dart';
import '../../domain/services/diet_calculator.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 饮食页：喂食计划（今日/明日/历史）+ AI 生成 + 偏好入口 + 热量估算。
class DietPage extends ConsumerStatefulWidget {
  const DietPage({super.key});

  @override
  ConsumerState<DietPage> createState() => _DietPageState();
}

class _DietPageState extends ConsumerState<DietPage> {
  bool _generating = false;
  String? _error;
  int _batchTotal = 1;
  int _batchDone = 0;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    if (pets.isEmpty) {
      return PageScaffold(
        title: '饮食',
        body: EmptyView(
          icon: Icons.pets,
          title: '先添加一只宠物吧',
          action: FilledButton(
            onPressed: () => context.push('/pet/new'),
            child: const Text('添加宠物'),
          ),
        ),
      );
    }
    final pet = ref.watch(currentPetProvider) ?? pets.first;
    final records = ref.watch(currentPetRecordsProvider);
    final profile = ref.watch(dietProfileProvider(pet.id)).valueOrNull;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final plans =
        ref.watch(dietPlansProvider(pet.id)).valueOrNull ?? const <MealPlan>[];
    // 生效计划：当天精确匹配，否则落到同星期的「周循环模板」。
    final todayPlan = DietCalculator.effectivePlan(plans, today);
    final tomorrowPlan = DietCalculator.effectivePlan(plans, tomorrow);
    final history = plans.where((p) => p.date.isBefore(today)).toList();

    final cs = Theme.of(context).colorScheme;
    final breed = findBreed(pet.breed, pet.species);
    final estimate = DietCalculator.dailyKcal(pet, records,
        breedTypicalKg: breed == null ? null : (breed.minKg + breed.maxKg) / 2);

    return PageScaffold(
      title: '${pet.name} · 饮食',
      actions: [
        const SyncButton(),
        IconButton(
          icon: const Icon(Icons.tune_outlined),
          tooltip: '饮食偏好',
          onPressed: () => context.push('/diet/preferences'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 热量估算 + 偏好摘要。
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('每日热量参考',
                          style: AppTheme.label(cs.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        estimate == null
                            ? '记录体重后可估算'
                            : '约 ${estimate.round()} kcal',
                        style:
                            AppTheme.bigNumber(cs.primary, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile == null
                        ? '还没填饮食偏好（爱吃/不爱吃/过敏源），填写后 AI 计划更准'
                        : '${profile.foodType.label} · 每天${profile.mealsPerDay}餐'
                            '${profile.brand == null || profile.brand!.isEmpty ? "" : " · ${profile.brand}"}'
                            '${profile.allergens.isEmpty ? "" : " · 过敏:${profile.allergens.join("、")}"}',
                    style: AppTheme.subhead(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('喂食计划'),
          _PlanCard(label: '今天', date: today, plan: todayPlan),
          const SizedBox(height: 10),
          _PlanCard(label: '明天', date: tomorrow, plan: tomorrowPlan),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _generating ? null : () => _chooseAndGenerate(pet, tomorrow),
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_generating
                ? _progressLabel
                : 'AI 生成喂食计划（单日 / 一周 / 月度循环）'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTheme.footnote(AppTheme.warnRed)),
          ],
          if (history.isNotEmpty) ...[
            const SectionTitle('历史计划'),
            ...history
                .take(7)
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _showPlanSheet(context, p),
                          title: Text(
                              '${p.date.month}/${p.date.day} · ${p.meals.length}餐'
                              '${p.totalKcal == null ? "" : " · ${p.totalKcal!.round()}kcal"}',
                              style: AppTheme.cardTitle(cs.onSurface)),
                          subtitle: Text(
                            p.meals.map((m) => m.name).join(' / '),
                            style: AppTheme.footnote(cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: p.repeatWeekly
                              ? TypeChip('周循环',
                                  color: AppTheme.warnAmber, compact: true)
                              : p.source == PlanSource.ai
                                  ? TypeChip('AI',
                                      color: cs.primary, compact: true)
                                  : null,
                        ),
                      ),
                    )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 生成入口：选择周期（单日 / 一周 / 月度周循环模板）。
  Future<void> _chooseAndGenerate(Pet pet, DateTime startDate) async {
    if (!await ensureWritable(ref, context, pet.id)) return;
    if (!mounted) return;
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text('生成多久的喂食计划？',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('只生成明天',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('单日计划，先试试效果', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, 'day'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('未来一周',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('连续 7 天，每天一份专属计划',
                  style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, 'week'),
            ),
            ListTile(
              leading: Icon(Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('一个月（周循环）',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('生成一周模板，之后每周自动重复执行',
                  style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, 'month'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    switch (mode) {
      case 'day':
        await _generate(pet, startDate);
      case 'week':
        await _generateBatch(pet, startDate, days: 7, repeat: false);
      case 'month':
        await _generateBatch(pet, startDate, days: 7, repeat: true);
    }
  }

  String get _progressLabel => _batchTotal > 1
      ? 'AI 正在生成 $_batchDone/$_batchTotal 天计划…'
      : 'AI 正在生成…';

  Future<void> _generateBatch(
    Pet pet,
    DateTime startDate, {
    required int days,
    required bool repeat,
  }) async {
    setState(() {
      _generating = true;
      _error = null;
      _batchTotal = days;
      _batchDone = 0;
    });
    try {
      final records = await ref.read(healthRepoProvider).getByPet(pet.id);
      final profile = await ref.read(dietRepoProvider).getProfile(pet.id);
      final breed = findBreed(pet.breed, pet.species);
      final plans = await ref.read(aiServiceProvider).generateDietPlanBatch(
            pet,
            records,
            profile,
            startDate: startDate,
            days: days,
            repeatWeekly: repeat,
            breedTypicalKg:
                breed == null ? null : (breed.minKg + breed.maxKg) / 2,
          );
      setState(() => _batchDone = plans.length);
      for (final plan in plans) {
        await ref.read(dietRepoProvider).savePlan(plan);
      }
      if (mounted) {
        showAutoToast(
          context,
          repeat
              ? '已生成一周模板，之后每周自动循环 ✅'
              : '已生成 ${plans.length} 天计划 ✅',
        );
      }
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// 单日计划（原逻辑保留，供「只生成明天」用）。
  Future<void> _generate(Pet pet, DateTime date) async {
    setState(() {
      _generating = true;
      _error = null;
      _batchTotal = 1;
      _batchDone = 0;
    });
    try {
      final records = await ref.read(healthRepoProvider).getByPet(pet.id);
      final profile = await ref.read(dietRepoProvider).getProfile(pet.id);
      final breed = findBreed(pet.breed, pet.species);
      final plan = await ref.read(aiServiceProvider).generateDietPlan(
            pet,
            records,
            profile,
            breedTypicalKg:
                breed == null ? null : (breed.minKg + breed.maxKg) / 2,
            forDate: date,
          );
      await ref.read(dietRepoProvider).savePlan(plan);
      if (mounted) showAutoToast(context, '计划已生成 ✅');
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showPlanSheet(BuildContext context, MealPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            _PlanDetail(plan: plan),
          ],
        ),
      ),
    );
  }
}

/// 喂食计划卡（一天）。
class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.label, required this.date, required this.plan});

  final String label;
  final DateTime date;
  final MealPlan? plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    if (plan == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(label, style: AppTheme.cardTitle(cs.onSurface)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '暂无计划，点下方按钮让 AI 安排',
                  style: AppTheme.subhead(cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final p = plan!;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [_PlanDetail(plan: p)],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: AppTheme.cardTitle(cs.onSurface)),
                  const SizedBox(width: 8),
                  if (p.repeatWeekly)
                    TypeChip(
                        date.year == p.date.year &&
                                date.month == p.date.month &&
                                date.day == p.date.day
                            ? '周循环'
                            : '周循环·模板${p.date.month}/${p.date.day}',
                        color: AppTheme.warnAmber,
                        compact: true)
                  else if (p.source == PlanSource.ai)
                    TypeChip('AI', color: cs.primary, compact: true),
                  const Spacer(),
                  if (p.totalKcal != null)
                    Text('${p.totalKcal!.round()} kcal',
                        style: AppTheme.bigNumber(cs.primary, size: 18)),
                ],
              ),
              const SizedBox(height: 10),
              for (final meal in p.meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(meal.time,
                            style: AppTheme.caption(cs.onSurfaceVariant)),
                      ),
                      Expanded(
                        child: Text(
                          meal.name +
                              (meal.grams == null
                                  ? ''
                                  : ' · ${meal.grams!.round()}g'),
                          style: AppTheme.subhead(cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (meal.kcal != null)
                        Text('${meal.kcal!.round()}kcal',
                            style: AppTheme.captionSm(cs.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 计划完整详情（每餐明细 + 鲜食食谱 + 建议）。
class _PlanDetail extends StatelessWidget {
  const _PlanDetail({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${plan.date.month}月${plan.date.day}日 喂食计划',
                style: AppTheme.title(cs.onSurface)),
            const Spacer(),
            if (plan.totalKcal != null)
              Text('${plan.totalKcal!.round()} kcal',
                  style: AppTheme.bigNumber(cs.primary, size: 22)),
          ],
        ),
        if (plan.waterMl != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('建议饮水 ${plan.waterMl!.round()} ml',
                style: AppTheme.footnote(cs.onSurfaceVariant)),
          ),
        const SizedBox(height: 12),
        for (final meal in plan.meals) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(meal.time,
                            style: AppTheme.caption(cs.primary)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(meal.name,
                            style: AppTheme.cardTitle(cs.onSurface)),
                      ),
                      if (meal.kcal != null)
                        Text('${meal.kcal!.round()}kcal',
                            style: AppTheme.footnote(cs.onSurfaceVariant)),
                    ],
                  ),
                  if (meal.grams != null) ...[
                    const SizedBox(height: 6),
                    Text('总量 ${meal.grams!.round()}g',
                        style: AppTheme.footnote(cs.onSurface)),
                  ],
                  if (meal.items.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...meal.items.map((i) => Text('· $i',
                        style: AppTheme.footnote(cs.onSurface))),
                  ],
                  if (meal.ingredients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('食材', style: AppTheme.label(cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: meal.ingredients
                          .map((i) => TypeChip(i, color: AppTheme.okGreen, compact: true))
                          .toList(),
                    ),
                  ],
                  if (meal.steps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('做法', style: AppTheme.label(cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    ...meal.steps.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text('${e.key + 1}. ${e.value}',
                                style: AppTheme.footnote(cs.onSurface)),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (plan.advice != null && plan.advice!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('建议', style: AppTheme.label(cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(plan.advice!, style: AppTheme.footnote(cs.onSurface)),
        ],
        if (plan.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final w in plan.warnings)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 16, color: AppTheme.warnAmber),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(w,
                        style: AppTheme.footnote(AppTheme.warnAmber))),
              ],
            ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

/// 某宠物的全部计划。
final dietPlansProvider =
    StreamProvider.family<List<MealPlan>, String>((ref, petId) {
  return ref.watch(dietRepoProvider).watchPlansByPet(petId);
});
