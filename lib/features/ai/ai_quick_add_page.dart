import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// AI 一句话记录：自然语言 → 结构化草稿 → 确认入库。
class AiQuickAddPage extends ConsumerStatefulWidget {
  const AiQuickAddPage({super.key});

  @override
  ConsumerState<AiQuickAddPage> createState() => _AiQuickAddPageState();
}

class _AiQuickAddPageState extends ConsumerState<AiQuickAddPage> {
  final _inputController = TextEditingController();
  bool _parsing = false;
  QuickAddDraft? _draft;
  String? _error;

  static const _examples = [
    '今天带豆豆打了狂犬疫苗花了200',
    '昨天称了体重5.4公斤',
    '上周六带它去海边玩了一下午',
    '体外驱虫了大宠爱',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _parsing) return;
    setState(() {
      _parsing = true;
      _error = null;
      _draft = null;
    });
    try {
      final pets = ref.read(petsProvider).valueOrNull ?? const <Pet>[];
      final draft = await ref
          .read(aiServiceProvider)
          .quickAdd(text, pets.map((p) => p.name).toList());
      setState(() => _draft = draft);
    } on AiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '解析失败：$e');
    } finally {
      setState(() => _parsing = false);
    }
  }

  Future<void> _confirm() async {
    final draft = _draft;
    if (draft == null) return;
    // 找到对应宠物（按名字匹配，失败取当前）。
    final pets = ref.read(petsProvider).valueOrNull ?? const <Pet>[];
    Pet? pet;
    for (final p in pets) {
      if (p.name == draft.petName) pet = p;
    }
    pet ??= ref.read(currentPetProvider);
    if (pet == null) {
      showAutoToast(context, '请先添加宠物');
      return;
    }
    if (!await ensureWritable(ref, context, pet.id)) return;
    if (!mounted) return;

    try {
      switch (draft.kind) {
        case QuickAddKind.health:
          await ref
              .read(healthRepoProvider)
              .upsert(_draftToHealthRecord(draft, pet.id));
          break;
        case QuickAddKind.expense:
          await ref
              .read(expenseRepoProvider)
              .upsert(_draftToExpense(draft, pet.id));
          break;
        case QuickAddKind.moment:
          await ref
              .read(momentRepoProvider)
              .upsert(_draftToMoment(draft, pet.id));
          break;
      }
      if (mounted) {
        showAutoToast(context, '已保存 ✅');
        context.pop();
      }
    } catch (e) {
      if (mounted) showAutoToast(context, '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final config = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 一句话记录')),
      body: !config.isReady
          ? EmptyView(
              icon: Icons.key_outlined,
              title: 'AI 还没有配置',
              subtitle: '配置 API 后即可用一句话快速记录',
              action: FilledButton(
                onPressed: () => context.push('/settings/ai'),
                child: const Text('去配置'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('说说发生了什么', style: AppTheme.title(cs.onSurface)),
                const SizedBox(height: 6),
                Text('AI 会解析成记录，确认后保存', style: AppTheme.subhead(cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextField(
                  controller: _inputController,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _parse(),
                  decoration: const InputDecoration(
                    hintText: '今天带豆豆打了狂犬疫苗花了200',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _parsing ? null : _parse,
                  icon: _parsing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_parsing ? '解析中…' : '解析'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _examples)
                      ActionChip(
                        label: Text(e, style: AppTheme.caption(cs.onSurface)),
                        onPressed: () {
                          _inputController.text = e;
                          _parse();
                        },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: AppTheme.footnote(AppTheme.warnRed)),
                ],
                if (_draft != null) ...[
                  const SizedBox(height: 20),
                  _DraftCard(draft: _draft!),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _draft = null),
                          child: const Text('不对，重新说'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _confirm,
                          child: const Text('确认保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// 解析结果预览卡。
class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft});

  final QuickAddDraft draft;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kindLabel = switch (draft.kind) {
      QuickAddKind.health => '健康记录',
      QuickAddKind.expense => '消费',
      QuickAddKind.moment => '时刻',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TypeChip(kindLabel, color: cs.primary),
                const SizedBox(width: 8),
                Text(Fmt.dateCn(draft.date),
                    style: AppTheme.footnote(cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            Text(draft.title.isEmpty ? '（未命名）' : draft.title,
                style: AppTheme.cardTitle(cs.onSurface)),
            const SizedBox(height: 8),
            if (draft.kind == QuickAddKind.health) ...[
              InfoRow('类型', draft.healthType.label),
              if (draft.value != null)
                InfoRow(
                    '数值',
                    draft.healthType == HealthRecordType.bcs
                        ? '${draft.value!.toInt()} 分'
                        : '${draft.value} kg'),
              if (draft.textValue.isNotEmpty) InfoRow('名称', draft.textValue),
              if (draft.cycleDays != null)
                InfoRow('周期', '${draft.cycleDays} 天'),
            ],
            if (draft.kind == QuickAddKind.expense) ...[
              InfoRow('分类', draft.expenseCategory.label),
              if (draft.amountYuan != null)
                InfoRow(
                    '金额',
                    Money.format(
                        (draft.amountYuan! * 100).round())),
            ],
            if (draft.kind == QuickAddKind.moment) ...[
              InfoRow('类型', draft.momentType.label),
              if (draft.location.isNotEmpty) InfoRow('地点', draft.location),
            ],
            if (draft.notes.isNotEmpty) InfoRow('备注', draft.notes),
            const SizedBox(height: 4),
            Text('将保存到：${draft.petName}',
                style: AppTheme.captionSm(cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// —— 草稿 → 领域对象 —— //

HealthRecord _draftToHealthRecord(QuickAddDraft d, String petId) =>
    HealthRecord(
      id: '',
      petId: petId,
      type: d.healthType,
      date: DateTime(d.date.year, d.date.month, d.date.day),
      value: d.value,
      textValue: d.textValue.isEmpty ? null : d.textValue,
      cycleDays: d.cycleDays,
      notes: d.notes.isEmpty ? null : d.notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

Expense _draftToExpense(QuickAddDraft d, String petId) => Expense(
      id: '',
      petId: petId,
      category: d.expenseCategory,
      title: d.title.isEmpty ? d.expenseCategory.label : d.title,
      amount: ((d.amountYuan ?? 0) * 100).round(),
      date: DateTime(d.date.year, d.date.month, d.date.day),
      notes: d.notes.isEmpty ? null : d.notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

Moment _draftToMoment(QuickAddDraft d, String petId) => Moment(
      id: '',
      petId: petId,
      type: d.momentType,
      date: DateTime(d.date.year, d.date.month, d.date.day),
      title: d.title.isEmpty ? d.momentType.label : d.title,
      notes: d.notes.isEmpty ? null : d.notes,
      location: d.location.isEmpty ? null : d.location,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
