import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// 添加 / 编辑消费。
class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key, this.existingId});

  final String? existingId;

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.food;
  String? _petId; // null = 全体
  DateTime _date = DateTime.now();
  List<String> _imagePaths = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.existingId != null) {
      final e =
          await ref.read(expenseRepoProvider).getById(widget.existingId!);
      if (e != null && mounted) {
        _category = e.category;
        _petId = e.petId;
        _date = e.date;
        _imagePaths = e.imagePaths;
        _titleController.text = e.title;
        _amountController.text = Money.toDecimalString(e.amount);
        _notesController.text = e.notes ?? '';
      }
    } else {
      // 新建默认当前宠物。
      _petId = ref.read(currentPetProvider)?.id;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
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
    final paths = await ImageStore.pickFromGallery(maxCount: 3);
    if (paths.isNotEmpty) setState(() => _imagePaths.addAll(paths));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;    if (!await ensureWritable(ref, context, _petId)) return;
    if (!mounted) return;

    final amount = Money.parse(_amountController.text);
    if (amount == null) {
      showAutoToast(context, '请输入正确的金额');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepoProvider).upsert(Expense(
            id: widget.existingId ?? '',
            petId: _petId,
            category: _category,
            title: _titleController.text.trim(),
            amount: amount,
            date: DateTime(_date.year, _date.month, _date.day),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            imagePaths: _imagePaths,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
      autoPushIfNeeded(ref, _petId);
      if (mounted) {
        showAutoToast(context, '已记录');
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
        title: const Text('删除这笔消费？'),
        content: const Text('删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.warnRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(expenseRepoProvider).delete(widget.existingId!);
    if (mounted) {
      showAutoToast(context, '已删除');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: loadingView);
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑消费' : '记一笔消费'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除消费',
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
              label: '分类',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values
                    .map((c) => SelectChip(
                          c.label,
                          selected: _category == c,
                          color: expenseCategoryColor(c),
                          onSelected: (_) => setState(() => _category = c),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            FormSection(
              label: '事项与金额',
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '事项',
                      hintText: '如 狂犬疫苗 / 买猫粮',
                    ),
                    style: AppTheme.body(cs.onSurface),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '写个事项吧' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '金额（元）',
                      prefixText: '¥ ',
                      hintText: '0.00',
                    ),
                    style: AppTheme.bigNumber(cs.onSurface, size: 20),
                    validator: (v) =>
                        Money.parse(v ?? '') == null ? '请输入金额' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FormSection(
              label: '归属与日期',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SelectChip(
                        '全体',
                        selected: _petId == null,
                        color: cs.onSurfaceVariant,
                        onSelected: (_) => setState(() => _petId = null),
                      ),
                      ...pets.map((p) => SelectChip(
                            p.name,
                            selected: p.id == _petId,
                            onSelected: (_) => setState(() => _petId = p.id),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: '日期',
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            FormSection(
              label: '备注与小票（$_imagePaths.length/3）',
              child: Column(
                children: [
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                    ),
                    style: AppTheme.body(cs.onSurface),
                  ),
                  if (_imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 76,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final path in _imagePaths)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  LocalImage(path, size: 70, borderRadius: 10),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _imagePaths.remove(path)),
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
                        ],
                      ),
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.receipt_long_outlined,
                            size: 18),
                        label: const Text('附小票/账单照片'),
                      ),
                    ),
                  if (_imagePaths.isNotEmpty && _imagePaths.length < 3)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: const Text('再加一张'),
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
