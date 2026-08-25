import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants/bcs.dart';
import '../../core/notifications/notification_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/health_record.dart';
import '../../shared/widgets/common.dart';

/// 添加 / 编辑健康记录。按类型动态展示字段。
class HealthRecordFormPage extends ConsumerStatefulWidget {
  const HealthRecordFormPage({super.key, this.existingId, this.initialType});

  final String? existingId;

  /// 从外部指定初始类型（如体重卡上的「+」）。
  final String? initialType;

  @override
  ConsumerState<HealthRecordFormPage> createState() =>
      _HealthRecordFormPageState();
}

class _HealthRecordFormPageState extends ConsumerState<HealthRecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _textController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  HealthRecordType _type = HealthRecordType.weight;
  DateTime _date = DateTime.now();
  int? _cycleDays;
  List<String> _imagePaths = [];
  bool _loading = true;
  bool _saving = false;
  String _petId = '';

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _type = HealthRecordType.fromName(widget.initialType);
    _load();
  }

  Future<void> _load() async {
    final pet = ref.read(currentPetProvider);
    _petId = pet?.id ?? '';
    if (widget.existingId != null) {
      final record =
          await ref.read(healthRepoProvider).getById(widget.existingId!);
      if (record != null && mounted) {
        _petId = record.petId;
        _type = record.type;
        _date = record.date;
        _cycleDays = record.cycleDays;
        _imagePaths = record.imagePaths;
        if (record.value != null) {
          _valueController.text = record.value! == record.value!.toInt()
              ? record.value!.toInt().toString()
              : record.value.toString();
        }
        _textController.text = record.textValue ?? '';
        _diagnosisController.text = record.diagnosis ?? '';
        _notesController.text = record.notes ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _textController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImages() async {
    final paths = await ImageStore.pickFromGallery(
        maxCount: 6 - _imagePaths.length);
    if (paths.isNotEmpty) setState(() => _imagePaths.addAll(paths));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;    if (!await ensureWritable(ref, context, _petId)) return;
    if (!mounted) return;

    if (_petId.isEmpty) {
      showAutoToast(context, '请先添加宠物');
      return;
    }
    setState(() => _saving = true);
    try {
      double? value;
      if (_type.hasValue) {
        value = double.tryParse(_valueController.text.trim());
        if (value == null) {
          showAutoToast(context, '请填写数值');
          return;
        }
      }
      await ref.read(healthRepoProvider).upsert(HealthRecord(
            id: widget.existingId ?? '',
            petId: _petId,
            type: _type,
            date: DateTime(_date.year, _date.month, _date.day),
            value: value,
            textValue: _textController.text.trim().isEmpty
                ? null
                : _textController.text.trim(),
            diagnosis: _diagnosisController.text.trim().isEmpty
                ? null
                : _diagnosisController.text.trim(),
            cycleDays: _type.supportsCycle ? _cycleDays : null,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            imagePaths: _imagePaths,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
      await _resyncReminders();
      autoPushIfNeeded(ref, _petId);
      if (mounted) {
        showAutoToast(context, '已保存');
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {    if (!await ensureWritable(ref, context, _petId)) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.warnRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(healthRepoProvider).delete(widget.existingId!);
    await _resyncReminders();
    if (mounted) {
      showAutoToast(context, '已删除');
      context.pop();
    }
  }

  /// 保存/删除后重排该宠物提醒（疫苗/驱虫到期可能变化）。
  Future<void> _resyncReminders() async {
    final pet = await ref.read(petRepoProvider).getById(_petId);
    if (pet == null) return;
    final settings = ref.read(appSettingsProvider);
    await NotificationService.syncPetReminders(
      pet,
      await ref.read(healthRepoProvider).getByPet(_petId),
      enabled: settings.reminderEnabled,
      daysBefore: settings.reminderDaysBefore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: loadingView);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑记录' : '健康记录'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除记录',
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormSection(
              label: '记录类型',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HealthRecordType.values
                    .map((t) => SelectChip(
                          t.label,
                          selected: _type == t,
                          color: recordTypeColor(t),
                          onSelected: (_) => setState(() => _type = t),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),

            // 类型专属字段。
            if (_type == HealthRecordType.weight)
              FormSection(
                label: '体重',
                child: TextFormField(
                  controller: _valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '体重（kg）',
                    hintText: '如 5.2',
                  ),
                  style: AppTheme.body(cs.onSurface),
                  validator: (v) =>
                      double.tryParse(v?.trim() ?? '') == null ? '请输入数字' : null,
                ),
              ),
            if (_type == HealthRecordType.bcs)
              FormSection(
                label: '体型评分（1-9 分）',
                child: _BcsSelector(
                  initial: double.tryParse(_valueController.text)?.toInt(),
                  onChanged: (score) => setState(() {
                    _valueController.text = score.toString();
                  }),
                ),
              ),
            if (_type.supportsCycle)
              FormSection(
                label: _type == HealthRecordType.vaccine ? '疫苗信息' : '驱虫信息',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _textController,
                      decoration: InputDecoration(
                        labelText: _type == HealthRecordType.vaccine
                            ? '疫苗名称'
                            : '驱虫药名称（可选）',
                        hintText: _type == HealthRecordType.vaccine
                            ? '如 狂犬疫苗 / 卫佳伍'
                            : '如 拜宠清 / 大宠爱',
                      ),
                      style: AppTheme.body(cs.onSurface),
                    ),
                    const SizedBox(height: 16),
                    Text('下次间隔', style: AppTheme.label(cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        (30, '30天'),
                        (90, '3个月'),
                        (180, '6个月'),
                        (365, '1年'),
                      ]
                          .map((e) => SelectChip(
                                e.$2,
                                selected: _cycleDays == e.$1,
                                color: cs.primary,
                                onSelected: (_) =>
                                    setState(() => _cycleDays = e.$1),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _type == HealthRecordType.vaccine
                          ? '不选则默认 1 年'
                          : _type == HealthRecordType.dewormIn
                              ? '不选则默认 3 个月'
                              : '不选则默认 30 天',
                      style: AppTheme.captionSm(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (_type == HealthRecordType.vetVisit)
              FormSection(
                label: '就诊信息',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: '医院',
                        hintText: '如 安安宠医（万达店）',
                      ),
                      style: AppTheme.body(cs.onSurface),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _diagnosisController,
                      decoration: const InputDecoration(
                        labelText: '诊断 / 结论',
                        hintText: '如 轻度肠胃炎',
                      ),
                      style: AppTheme.body(cs.onSurface),
                    ),
                  ],
                ),
              ),
            if (_type == HealthRecordType.medication)
              FormSection(
                label: '用药信息',
                child: TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: '药品名称',
                    hintText: '如 益生菌 / 速诺',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
              ),
            if (_type == HealthRecordType.symptom)
              FormSection(
                label: '症状',
                child: TextFormField(
                  controller: _diagnosisController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '症状描述',
                    hintText: '如 呕吐两次、精神不佳',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
              ),
            const SizedBox(height: 12),

            FormSection(
              label: '日期',
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '记录日期',
                    suffixIcon: Icon(Icons.calendar_today_outlined,
                        size: 20, color: cs.primary),
                  ),
                  child: Text(
                    '${_date.year}年${_date.month}月${_date.day}日',
                    style: AppTheme.body(cs.onSurface).copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            FormSection(
              label: '备注与照片（$_imagePaths.length/6）',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                    ),
                    style: AppTheme.body(cs.onSurface),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 86,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final path in _imagePaths)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                LocalImage(path, size: 80, borderRadius: 10),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _imagePaths.remove(path)),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_imagePaths.length < 6)
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Icon(Icons.add_photo_alternate_outlined,
                                  color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
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
      ),
    );
  }
}

/// BCS 1-9 图解选择器：分档色带 + 触诊描述。
class _BcsSelector extends StatelessWidget {
  const _BcsSelector({required this.initial, this.onChanged});

  final int? initial;
  final ValueChanged<int>? onChanged;
  static const _bands = {
    '极瘦': AppTheme.warnRed,
    '偏瘦': AppTheme.warnAmber,
    '理想': AppTheme.okGreen,
    '偏胖': AppTheme.warnAmber,
    '肥胖': AppTheme.warnRed,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var score = 1; score <= 9; score++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged?.call(score),
                  child: AspectRatio(
                    aspectRatio: 0.75,
                    child: Container(
                      margin: EdgeInsets.only(right: score == 9 ? 0 : 4),
                      decoration: BoxDecoration(
                        color: initial == score
                            ? cs.primary
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: initial == score
                            ? null
                            : Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$score',
                            style: AppTheme.bigNumber(
                              initial == score ? Colors.white : cs.onSurface,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bcsBand(score),
                            style: AppTheme.captionSm(
                              initial == score
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (initial != null) ...[
          const SizedBox(height: 8),
          for (final level in kBcsLevels)
            if (level.score == initial)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bands[level.band]!.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(level.description,
                    style: AppTheme.footnote(cs.onSurface)),
              ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('摸肋骨 + 看腰线，选最接近的一档',
                style: AppTheme.captionSm(cs.onSurfaceVariant)),
          ),
      ],
    );
  }
}
