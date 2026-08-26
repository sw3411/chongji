import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/photo_exif.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// 添加 / 编辑时刻。
class MomentFormPage extends ConsumerStatefulWidget {
  const MomentFormPage({super.key, this.existingId});

  final String? existingId;

  @override
  ConsumerState<MomentFormPage> createState() => _MomentFormPageState();
}

class _MomentFormPageState extends ConsumerState<MomentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();

  MomentType _type = MomentType.custom;
  DateTime _date = DateTime.now();
  List<String> _imagePaths = [];
  String _petId = '';
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pet = ref.read(currentPetProvider);
    _petId = pet?.id ?? '';
    if (widget.existingId != null) {
      final m = await ref.read(momentRepoProvider).getById(widget.existingId!);
      if (m != null && mounted) {
        _petId = m.petId;
        _type = m.type;
        _date = m.date;
        _imagePaths = m.imagePaths;
        _titleController.text = m.title;
        _notesController.text = m.notes ?? '';
        _locationController.text = m.location ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImages() async {
    final picked = await ImageStore.pickFromGalleryWithExif(
        maxCount: 9 - _imagePaths.length);
    if (picked.isEmpty) return;
    setState(() => _imagePaths.addAll(picked.map((e) => e.$1)));

    // 按第一张有信息的照片自动填日期与位置（多张不一致以第一张为准）。
    PhotoExif? firstWithDate;
    PhotoExif? firstWithGps;
    for (final (_, exif) in picked) {
      firstWithDate ??= exif.takenAt != null ? exif : null;
      firstWithGps ??= (exif.lat != null && exif.lng != null) ? exif : null;
      if (firstWithDate != null && firstWithGps != null) break;
    }
    final tips = <String>[];
    final date = firstWithDate?.takenAt;
    if (date != null) {
      setState(() => _date = DateTime(date.year, date.month, date.day));
      tips.add('日期 ${date.month}月${date.day}日');
    }
    final gps = firstWithGps;
    if (gps?.lat != null && gps?.lng != null) {
      final place = await PhotoExifReader.placeName(gps!.lat!, gps.lng!);
      if (place != null && place.isNotEmpty) {
        setState(() => _locationController.text = place);
        tips.add('位置 $place');
      }
    }
    if (mounted) {
      if (tips.isNotEmpty) {
        showAutoToast(context, '已按照片自动填写：${tips.join('，')}');
      } else {
        // 一张照片都没读出时间/位置：明确告知原因，避免“没反应”的困惑。
        showAutoToast(context,
            '照片里没有拍摄时间/位置信息（截图、微信图片常见），请手动确认日期');
      }
    }
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
      await ref.read(momentRepoProvider).upsert(Moment(
            id: widget.existingId ?? '',
            petId: _petId,
            type: _type,
            date: DateTime(_date.year, _date.month, _date.day),
            title: _titleController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            imagePaths: _imagePaths,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
      autoPushIfNeeded(ref, _petId);
      if (mounted) {
        HapticFeedback.mediumImpact();
        showAutoToast(context, '已保存 📸');
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
        title: const Text('删除这个时刻？'),
        content: const Text('照片记录删除后不可恢复。'),
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
    await ref.read(momentRepoProvider).delete(widget.existingId!);
    if (mounted) {
      showAutoToast(context, '已删除');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(body: loadingView);
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑时刻' : '记录时刻'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除时刻',
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: FormSaveBar(
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pets.length > 1) ...[
              FormSection(
                label: '属于',
                child: Wrap(
                  spacing: 8,
                  children: pets
                      .map((p) => SelectChip(
                            p.name,
                            selected: p.id == _petId,
                            onSelected: (_) => setState(() => _petId = p.id),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FormSection(
              label: '类型与日期',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MomentType.values
                        .map((t) => SelectChip(
                              t.label,
                              selected: _type == t,
                              color: momentTypeColor(t),
                              onSelected: (_) => setState(() => _type = t),
                            ))
                        .toList(),
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
              label: '这一刻',
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '如 去海边玩水啦',
                    ),
                    style: AppTheme.body(cs.onSurface),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '写个标题吧' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: '地点（可选）',
                      hintText: '如 青岛金沙滩',
                    ),
                    style: AppTheme.body(cs.onSurface),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '记录（可选）',
                      hintText: '今天发生了什么？',
                    ),
                    style: AppTheme.body(cs.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FormSection(
              label: '照片（$_imagePaths.length/9）',
              child: SizedBox(
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
                    if (_imagePaths.length < 9)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color:
                              cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
