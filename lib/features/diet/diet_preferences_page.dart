import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/diet_profile.dart';
import '../../domain/models/enums.dart';
import '../../shared/widgets/common.dart';

/// 饮食偏好：主食类型 / 品牌 / 每日餐数 / 爱吃 / 不爱吃 / 过敏源。
class DietPreferencesPage extends ConsumerStatefulWidget {
  const DietPreferencesPage({super.key});

  @override
  ConsumerState<DietPreferencesPage> createState() =>
      _DietPreferencesPageState();
}

class _DietPreferencesPageState extends ConsumerState<DietPreferencesPage> {
  FoodType _foodType = FoodType.mixed;
  final _brandController = TextEditingController();
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _allergensController = TextEditingController();
  final _notesController = TextEditingController();
  int _mealsPerDay = 2;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pet = ref.read(currentPetProvider);
    if (pet != null) {
      final profile = await ref.read(dietRepoProvider).getProfile(pet.id);
      if (profile != null && mounted) {
        _foodType = profile.foodType;
        _brandController.text = profile.brand ?? '';
        _likesController.text = profile.likes.join('、');
        _dislikesController.text = profile.dislikes.join('、');
        _allergensController.text = profile.allergens.join('、');
        _notesController.text = profile.notes ?? '';
        _mealsPerDay = profile.mealsPerDay;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _brandController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    _allergensController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static List<String> _split(String text) => text
      .split(RegExp(r'[、,，\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final pet = ref.read(currentPetProvider);
    if (pet == null) {
      showAutoToast(context, '请先添加宠物');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dietRepoProvider).saveProfile(DietProfile(
            petId: pet.id,
            foodType: _foodType,
            brand: _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            likes: _split(_likesController.text),
            dislikes: _split(_dislikesController.text),
            allergens: _split(_allergensController.text),
            mealsPerDay: _mealsPerDay,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            updatedAt: DateTime.now(),
          ));
      if (mounted) {
        showAutoToast(context, '偏好已保存，AI 计划会更懂它');
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(body: loadingView);
    final pet = ref.watch(currentPetProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${pet?.name ?? ""}的饮食偏好')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSection(
            label: '主食习惯',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    (FoodType.kibble, '干粮/狗粮猫粮', AppTheme.infoBlue),
                    (FoodType.fresh, '鲜食/自制', AppTheme.okGreen),
                    (FoodType.mixed, '混搭', AppTheme.warnAmber),
                  ]
                      .map((e) => SelectChip(
                            e.$2,
                            selected: _foodType == e.$1,
                            color: e.$3,
                            onSelected: (_) => setState(() => _foodType = e.$1),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: '常用品牌（可选）',
                    hintText: '如 渴望 / 网易严选',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
                const SizedBox(height: 16),
                Text('每天几餐', style: AppTheme.label(cs.onSurfaceVariant)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 2, 3, 4]
                      .map((n) => SelectChip(
                            '$n餐',
                            selected: _mealsPerDay == n,
                            color: cs.primary,
                            onSelected: (_) => setState(() => _mealsPerDay = n),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FormSection(
            label: '口味与过敏',
            child: Column(
              children: [
                TextFormField(
                  controller: _likesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '爱吃的',
                    hintText: '如 鸡肉、冻干、胡萝卜（顿号分隔）',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dislikesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '不爱吃的',
                    hintText: '如 羊肉、青椒',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _allergensController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '过敏源（AI 会严格避开）',
                    hintText: '如 牛肉、鸡蛋',
                    labelStyle: const TextStyle(color: AppTheme.warnRed),
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '其他说明（可选）',
                    hintText: '如 换粮要 7 天过渡、胃口小',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
