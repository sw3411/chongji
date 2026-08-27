import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants/breeds.dart';
import '../../core/notifications/notification_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// 添加 / 编辑宠物。新建时可选填初始体重（自动生成一条体重记录）。
class PetFormPage extends ConsumerStatefulWidget {
  const PetFormPage({super.key, this.existingId});

  final String? existingId;

  @override
  ConsumerState<PetFormPage> createState() => _PetFormPageState();
}

class _PetFormPageState extends ConsumerState<PetFormPage> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  PetSpecies _species = PetSpecies.dog;
  PetGender _gender = PetGender.unknown;
  bool _neutered = false;
  DateTime? _birthday;
  DateTime? _adoptionDate;
  String? _avatarPath;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadExisting() async {
    final pet = await ref.read(petRepoProvider).getById(widget.existingId!);
    if (pet != null && mounted) {
      _nameController.text = pet.name;
      _breedController.text = pet.breed ?? '';
      _notesController.text = pet.notes ?? '';
      setState(() {
        _species = pet.species;
        _gender = pet.gender;
        _neutered = pet.neutered;
        _birthday = pet.birthday;
        _adoptionDate = pet.adoptionDate;
        _avatarPath = pet.avatarPath;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('移除头像'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == 'camera') {
      final path = await ImageStore.pickFromCamera();
      if (path != null) setState(() => _avatarPath = path);
    } else if (action == 'gallery') {
      final paths = await ImageStore.pickFromGallery(maxCount: 1);
      if (paths.isNotEmpty) setState(() => _avatarPath = paths.first);
    } else if (action == 'remove') {
      setState(() => _avatarPath = null);
    }
  }

  Future<DateTime?> _pickDate(DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 1),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isEdit &&
        !await ensureWritable(ref, context, widget.existingId)) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    // 记录保存前是否还没有任何宠物（首只 → 保存后进首页）。
    final hadPets = (ref.read(petsProvider).valueOrNull ?? const <Pet>[])
        .where((p) => !p.isDeleted)
        .isNotEmpty;
    try {
      final repo = ref.read(petRepoProvider);
      final now = DateTime.now();
      final existing =
          _isEdit ? await repo.getById(widget.existingId!) : null;
      final pet = Pet(
        id: existing?.id ?? _uuid.v4(),
        name: _nameController.text.trim(),
        species: _species,
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        birthday: _birthday,
        adoptionDate: _adoptionDate,
        gender: _gender,
        neutered: _neutered,
        avatarPath: _avatarPath,
        notes:
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: existing?.deletedAt,
      );
      await repo.upsert(pet);

      // 新建时填了初始体重 → 自动生成体重记录。
      if (!_isEdit) {
        final weight = double.tryParse(_weightController.text.trim());
        if (weight != null && weight > 0) {
          await ref.read(healthRepoProvider).upsert(HealthRecord(
                id: '',
                petId: pet.id,
                type: HealthRecordType.weight,
                date: DateTime(now.year, now.month, now.day),
                value: weight,
                createdAt: now,
                updatedAt: now,
              ));
        }
        ref.read(currentPetIdProvider.notifier).select(pet.id);
      }

      autoPushIfNeeded(ref, _isEdit ? widget.existingId : null);
      // 重排生日/到家纪念日提醒。
      final settings = ref.read(appSettingsProvider);
      await NotificationService.syncPetReminders(
        pet,
        await ref.read(healthRepoProvider).getByPet(pet.id),
        enabled: settings.reminderEnabled,
        daysBefore: settings.reminderDaysBefore,
      );
      await rescheduleDailyDigest(ref.read);

      if (mounted) {
        showAutoToast(context, _isEdit ? '已保存' : '${pet.name} 已加入家庭 🎉');
        if (!_isEdit && !hadPets) {
          context.go('/home');
        } else {
          context.pop();
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_loaded) return Scaffold(body: loadingView);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑档案' : '添加宠物'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    PetAvatar(
                      path: _avatarPath,
                      speciesIcon: Icons.pets,
                      size: 104,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            FormSection(
              label: '基本信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '名字',
                      hintText: '它叫什么？',
                    ),
                    style: AppTheme.body(cs.onSurface),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '填个名字吧' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('物种', style: AppTheme.label(cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      (PetSpecies.dog, '狗', AppTheme.okGreen, Icons.pets),
                      (PetSpecies.cat, '猫', AppTheme.warnAmber,
                          Icons.pets_outlined),
                      (PetSpecies.other, '其他', AppTheme.infoBlue,
                          Icons.help_outline),
                    ]
                        .map((e) => SelectChip(
                              e.$2,
                              selected: _species == e.$1,
                              color: e.$3,
                              icon: e.$4,
                              onSelected: (_) {
                                setState(() {
                                  _species = e.$1;
                                  _breedController.clear();
                                });
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _BreedField(
                    controller: _breedController,
                    species: _species,
                  ),
                  const SizedBox(height: 16),
                  Text('性别', style: AppTheme.label(cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      (PetGender.male, '男孩', AppTheme.infoBlue),
                      (PetGender.female, '女孩', AppTheme.rose),
                      (PetGender.unknown, '不填', cs.onSurfaceVariant),
                    ]
                        .map((e) => SelectChip(
                              e.$2,
                              selected: _gender == e.$1,
                              color: e.$3,
                              onSelected: (_) => setState(() => _gender = e.$1),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('已绝育', style: AppTheme.body(cs.onSurface)),
                    subtitle: Text('影响 AI 热量估算',
                        style: AppTheme.caption(cs.onSurfaceVariant)),
                    value: _neutered,
                    onChanged: (v) => setState(() => _neutered = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            FormSection(
              label: '生日与到家（都会作为纪念日提醒）',
              child: Column(
                children: [
                  _DateField(
                    label: '生日',
                    hint: '用于年龄与生日提醒',
                    date: _birthday,
                    onPick: () async {
                      final d = await _pickDate(_birthday);
                      if (d != null) setState(() => _birthday = d);
                    },
                    onClear: () => setState(() => _birthday = null),
                  ),
                  const SizedBox(height: 12),
                  _DateField(
                    label: '到家日期',
                    hint: '用于「到家纪念日」提醒',
                    date: _adoptionDate,
                    onPick: () async {
                      final d = await _pickDate(_adoptionDate);
                      if (d != null) setState(() => _adoptionDate = d);
                    },
                    onClear: () => setState(() => _adoptionDate = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!_isEdit) ...[
              FormSection(
                label: '当前体重（可选，自动生成体重记录）',
                child: TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '体重（kg）',
                    hintText: '如 5.2',
                  ),
                  style: AppTheme.body(cs.onSurface),
                ),
              ),
              const SizedBox(height: 12),
            ],

            FormSection(
              label: '备注（可选）',
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '性格、习惯、注意事项…',
                ),
                style: AppTheme.body(cs.onSurface),
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
                  : Text(_isEdit ? '保存修改' : '完成添加'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 品种输入：点开可搜索的品种选择器；也支持直接自定义输入。
class _BreedField extends StatelessWidget {
  const _BreedField({required this.controller, required this.species});

  final TextEditingController controller;
  final PetSpecies species;

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BreedPickerSheet(species: species),
    );
    if (picked != null && picked.isNotEmpty) {
      controller.text = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final breeds = breedsFor(species);
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _openPicker(context),
      decoration: InputDecoration(
        labelText: '品种',
        hintText: '${breeds.length}+ 常见品种，点此选择或搜索',
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _openPicker(context),
        ),
      ),
      style: AppTheme.body(cs.onSurface),
    );
  }
}

/// 品种选择器：搜索过滤 + 常见列表 + 使用自定义名称。
class _BreedPickerSheet extends StatefulWidget {
  const _BreedPickerSheet({required this.species});

  final PetSpecies species;

  @override
  State<_BreedPickerSheet> createState() => _BreedPickerSheetState();
}

class _BreedPickerSheetState extends State<_BreedPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = breedsFor(widget.species);
    final query = _query.trim();
    final filtered = query.isEmpty
        ? all
        : all
            .where((b) => b.name.split('/').any((seg) => seg.contains(query)))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            Text('选择品种',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '搜索品种，如「可卡」「灵」',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              style: AppTheme.body(cs.onSurface),
            ),
            const SizedBox(height: 10),
            if (query.isNotEmpty && filtered.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 40, color: cs.outline),
                    const SizedBox(height: 8),
                    Text('库中没有找到「$query」',
                        style: AppTheme.subhead(cs.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(context, query),
                      child: Text('使用自定义品种「$query」'),
                    ),
                  ],
                ),
              ),
            ] else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final b = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text(b.name, style: AppTheme.subhead(cs.onSurface)),
                      trailing: Text(b.rangeLabel,
                          style: AppTheme.caption(cs.onSurfaceVariant)),
                      onTap: () => Navigator.pop(context, b.name),
                    );
                  },
                ),
              ),
            if (query.isNotEmpty && filtered.isNotEmpty) ...[
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, query),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text('不在库中？使用「$query」'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 只读日期行：点击选择、可清除。
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.hint,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String hint;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: date == null ? hint : null,
          suffixIcon: date == null
              ? const Icon(Icons.calendar_today_outlined, size: 20)
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '清除',
                  onPressed: onClear,
                ),
        ),
        child: date == null
            ? Text('未填写', style: AppTheme.subhead(cs.onSurfaceVariant))
            : Text(
                '${date!.year}年${date!.month}月${date!.day}日',
                style: AppTheme.body(cs.onSurface).copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }
}
