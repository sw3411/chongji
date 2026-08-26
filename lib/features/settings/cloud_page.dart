import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/cloud/space_sync.dart';
import '../../core/cloud/tos_client.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/cloud_space.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// 云空间：按宠物共享数据到火山 TOS（加密）。
/// - 管理/编辑：配置 AK/SK 后可推送
/// - 查看：只输暗号+密码，零配置
class CloudPage extends ConsumerStatefulWidget {
  const CloudPage({super.key});

  @override
  ConsumerState<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends ConsumerState<CloudPage> {
  bool _busy = false;
  String? _message;

  Future<T?> _run<T>(Future<T> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      return await action();
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final spaces = ref.watch(cloudSpacesProvider).valueOrNull ?? const <CloudSpace>[];
    CloudSpace? spaceOf(String petId) {
      for (final s in spaces) {
        if (s.petId == petId) return s;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('云空间')),
      body: _busy && _message == null
          ? loadingView
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('共享一只宠物', style: AppTheme.cardTitle(cs.onSurface)),
                        const SizedBox(height: 8),
                        Text(
                          '数据以端到端加密存到你的火山引擎 TOS 桶：'
                          '「查看」成员只需暗号+密码，零配置；'
                          '「编辑/管理」成员额外配置桶的写入密钥。'
                          '注意：「全体」消费不参与共享；密码丢失可用恢复码找回。',
                          style: AppTheme.footnote(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('我的宠物空间'),
                for (final pet in pets)
                  _SpaceRow(
                    pet: pet,
                    space: spaceOf(pet.id),
                    onOpen: (space) => _syncSpace(space),
                    onManage: (space) => _manageSpace(space),
                    onEnable: () => _createDialog(pet),
                    onLeave: (space) => _leaveSpace(space),
                  ),
                if (pets.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('先添加宠物后才能开启共享',
                          style: AppTheme.subhead(cs.onSurfaceVariant)),
                    ),
                  ),
                const SectionTitle('加入别人的空间'),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.group_add_outlined,
                        color: cs.primary),
                    title: Text('输入暗号加入',
                        style: AppTheme.cardTitle(cs.onSurface)),
                    subtitle: Text('家人或朋友把暗号+密码发你即可',
                        style: AppTheme.footnote(cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _joinDialog,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!,
                      style: AppTheme.footnote(AppTheme.warnRed)),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ---------- 同步 / 管理 ----------

  Future<void> _syncSpace(CloudSpace space) async {
    await _run(() async {
      final outcome = await ref.read(spaceSyncProvider).sync(space);
      if (!mounted) return;
      setState(() => _message = null);
      showAutoToast(context, switch (outcome) {
            SyncOutcome.pushed => '已同步并推送最新修改 ✅',
            SyncOutcome.pulled => '已拉取最新数据（本地无修改）',
            SyncOutcome.upToDate => '已是最新，无修改不同步',
          });
    });
  }

  Future<void> _leaveSpace(CloudSpace space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出这个空间？'),
        content: const Text('仅解绑本机（数据保留在本地和云端），不影响其他成员。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(spaceSyncProvider).leaveSpace(space);
      if (mounted) showAutoToast(context, '已退出');
    }
  }

  Future<void> _manageSpace(CloudSpace space) async {
    final dataKey = await SpaceSync.loadDataKey(space.code);
    if (dataKey == null) {
      if (mounted) showAutoToast(context, '本机空间密钥丢失，请退出后重新加入');
      return;
    }
    final client = TosClient(
      endpoint: space.endpoint,
      bucket: space.bucket,
      accessKey: space.accessKey,
      secretKey: space.secretKey,
    );
    final manifest =
        await _run(() => SpaceSync.fetchManifest(client, space.code, dataKey));
    if (manifest == null || !mounted) return;
    final pageContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (sheetCtx, controller) => _ManageSheet(
          space: space,
          manifest: manifest,
          onMembers: (members) => _run(() async {
            await ref.read(spaceSyncProvider).updateMembers(space, members);
            if (pageContext.mounted) showAutoToast(pageContext, '成员已更新');
          }),
          onPassword: (pass) => _run(() async {
            final recovery = await ref
                .read(spaceSyncProvider)
                .changePassphrase(space, pass);
            if (pageContext.mounted) {
              Navigator.of(sheetCtx).pop();
              _showRecovery(pageContext, recovery,
                  title: '密码已修改', note: '新恢复码（旧恢复码已失效）：');
            }
          }),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ---------- 创建 ----------

  Future<void> _createDialog(Pet pet) async {
    final controllers = List.generate(
        5, (_) => TextEditingController()); // 昵称/桶/endpoint/AK/SK
    final passCtl = TextEditingController();
    final pass2Ctl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('为「${pet.name}」开启共享'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: controllers[0],
                    decoration: const InputDecoration(labelText: '你的昵称')),
                const SizedBox(height: 10),
                TextField(
                    controller: controllers[1],
                    decoration: const InputDecoration(
                        labelText: 'Bucket 名', hintText: '如 chongji-sync')),
                const SizedBox(height: 10),
                TextField(
                    controller: controllers[2],
                    decoration: const InputDecoration(
                        labelText: 'S3 兼容 Endpoint',
                        hintText: 'tos-s3-cn-beijing.volces.com')),
                const SizedBox(height: 10),
                TextField(
                    controller: controllers[3],
                    decoration: const InputDecoration(labelText: 'AccessKey')),
                const SizedBox(height: 10),
                TextField(
                    controller: controllers[4],
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'SecretKey')),
                const SizedBox(height: 10),
                TextField(
                    controller: passCtl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '空间密码')),
                const SizedBox(height: 10),
                TextField(
                    controller: pass2Ctl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: '确认空间密码')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('创建')),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    if (passCtl.text.trim().length < 6) {
      showAutoToast(context, '密码至少 6 位');
      return;
    }
    if (passCtl.text != pass2Ctl.text) {
      showAutoToast(context, '两次密码不一致');
      return;
    }
    final recovery = await _run(() => ref.read(spaceSyncProvider).createSpace(
          CloudSpace(
            petId: pet.id,
            code: '',
            endpoint: controllers[2].text.trim(),
            bucket: controllers[1].text.trim(),
            role: 'manage',
            memberName: controllers[0].text.trim().isEmpty
                ? '我'
                : controllers[0].text.trim(),
            accessKey: controllers[3].text.trim(),
            secretKey: controllers[4].text.trim(),
            createdAt: DateTime.now(),
          ),
          passCtl.text,
          pet,
        ));
    if (recovery != null && mounted) {
      _showRecovery(context, recovery,
          title: '空间已创建 🎉',
          note: '恢复码（密码丢失时唯一救济，请抄写保存）：');
    }
  }

  void _showRecovery(BuildContext pageContext, String recovery,
      {required String title, required String note}) {
    showDialog<void>(
      context: pageContext,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note, style: AppTheme.footnote(Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(recovery,
                  style: AppTheme.bigNumber(Theme.of(context).colorScheme.primary, size: 18)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recovery));
              showAutoToast(pageContext, '已复制');
            },
            child: const Text('复制'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('我已保存')),
        ],
      ),
    );
  }

  // ---------- 加入 ----------

  Future<void> _joinDialog() async {
    final c = List.generate(6, (_) => TextEditingController());
    // 0 endpoint 1 bucket 2 暗号 3 密码 4 昵称 5 AK（查看者留空）
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('加入空间'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: c[0],
                    decoration: const InputDecoration(
                        labelText: 'Endpoint',
                        hintText: 'tos-s3-cn-beijing.volces.com')),
                const SizedBox(height: 10),
                TextField(
                    controller: c[1],
                    decoration: const InputDecoration(labelText: 'Bucket 名')),
                const SizedBox(height: 10),
                TextField(
                    controller: c[2],
                    decoration: const InputDecoration(
                        labelText: '空间暗号', hintText: 'CJ-XXXX-XXXX-…')),
                const SizedBox(height: 10),
                TextField(
                    controller: c[3],
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '空间密码（或恢复码）')),
                const SizedBox(height: 10),
                TextField(
                    controller: c[4],
                    decoration: const InputDecoration(labelText: '你的昵称')),
                const SizedBox(height: 10),
                TextField(
                    controller: c[5],
                    decoration: const InputDecoration(
                        labelText: 'AK/SK（查看者留空，编辑/管理必填）',
                        hintText: 'AK,SK 用英文逗号分隔')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('加入')),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    final keys = c[5].text.trim().split(',');
    final hasKeys = keys.length == 2 && keys[0].isNotEmpty && keys[1].isNotEmpty;
    await _run(() => ref.read(spaceSyncProvider).joinSpace(
          endpoint: c[0].text.trim(),
          bucket: c[1].text.trim(),
          code: c[2].text.trim(),
          passphrase: c[3].text,
          memberName: c[4].text.trim().isEmpty ? '我' : c[4].text.trim(),
          role: hasKeys ? 'edit' : 'view',
          accessKey: hasKeys ? keys[0].trim() : '',
          secretKey: hasKeys ? keys[1].trim() : '',
        ));
    if (_message == null && mounted) {
      showAutoToast(context, '已加入，数据已同步到本机 ✅');
    }
  }
}

/// 单个宠物的空间状态卡：头部 + 结构化配置块 + 操作行。
class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.pet,
    required this.space,
    required this.onOpen,
    required this.onManage,
    required this.onEnable,
    required this.onLeave,
  });

  final Pet pet;
  final CloudSpace? space;
  final Future<void> Function(CloudSpace) onOpen;
  final Future<void> Function(CloudSpace) onManage;
  final VoidCallback onEnable;
  final Future<void> Function(CloudSpace) onLeave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = space;
    if (s == null) {
      return Card(
        child: ListTile(
          leading: PetAvatar(path: pet.avatarPath, size: 44),
          title: Text(pet.name, style: AppTheme.cardTitle(cs.onSurface)),
          subtitle: Text('未开启共享', style: AppTheme.footnote(cs.onSurfaceVariant)),
          trailing: FilledButton.tonal(
            onPressed: onEnable,
            child: const Text('开启'),
          ),
        ),
      );
    }
    final roleColor = s.role == 'manage'
        ? AppTheme.infoBlue
        : s.role == 'edit'
            ? AppTheme.okGreen
            : AppTheme.inkSecondary;
    final syncText = s.lastSyncAt == null
        ? '从未同步'
        : '上次同步 ${Fmt.relativeDay(s.lastSyncAt!)} '
            '${s.lastSyncAt!.hour}:${s.lastSyncAt!.minute.toString().padLeft(2, '0')}';

    Widget configRow(String label, String value, {Widget? trailing}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(label, style: AppTheme.captionSm(cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: AppTheme.caption(cs.onSurface).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    final akMask = s.accessKey.isEmpty
        ? '未配置（查看模式，零凭证）'
        : '${s.accessKey.length <= 8 ? s.accessKey : s.accessKey.substring(0, 8)}****';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：头像 + 名字 + 角色徽标。
            Row(
              children: [
                PetAvatar(path: pet.avatarPath, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(pet.name, style: AppTheme.cardTitle(cs.onSurface)),
                ),
                DatePill('${s.roleLabel}权限', color: roleColor),
              ],
            ),
            const SizedBox(height: 10),
            // 配置块。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  configRow(
                    '暗号',
                    s.code,
                    trailing: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      tooltip: '复制暗号',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: s.code));
                        showAutoToast(context, '暗号已复制');
                      },
                    ),
                  ),
                  configRow('桶名', s.bucket),
                  configRow('地址', s.endpoint),
                  configRow('写入', akMask),
                  configRow('同步', '$syncText · v${s.lastVersion}'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 操作行。
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => onOpen(s),
                  icon: const Icon(Icons.sync_rounded, size: 17),
                  label: const Text('立即同步'),
                ),
                const SizedBox(width: 8),
                if (s.canManage)
                  TextButton(
                      onPressed: () => onManage(s),
                      child: const Text('管理')),
                TextButton(
                  onPressed: () => onLeave(s),
                  style:
                      TextButton.styleFrom(foregroundColor: AppTheme.warnRed),
                  child: const Text('退出'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 管理面板：成员编辑 + 改密码。
class _ManageSheet extends StatefulWidget {
  const _ManageSheet({
    required this.space,
    required this.manifest,
    required this.onMembers,
    required this.onPassword,
  });

  final CloudSpace space;
  final SpaceManifest manifest;
  final Future<void> Function(List<SpaceMember>) onMembers;
  final Future<void> Function(String) onPassword;

  @override
  State<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends State<_ManageSheet> {
  late List<SpaceMember> _members;
  final _newName = TextEditingController();
  String _newRole = 'view';
  final _pass = TextEditingController();

  @override
  void initState() {
    super.initState();
    _members = [...widget.manifest.members];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('空间管理 · v${widget.manifest.version}',
            style: AppTheme.title(cs.onSurface)),
        const SizedBox(height: 4),
        Text('「${widget.manifest.petName}」 · 改密码后旧密码立即失效（踢人用）',
            style: AppTheme.footnote(cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (var i = 0; i < _members.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_members[i].name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: _members[i].role,
                  items: const [
                    DropdownMenuItem(value: 'manage', child: Text('管理')),
                    DropdownMenuItem(value: 'edit', child: Text('编辑')),
                    DropdownMenuItem(value: 'view', child: Text('查看')),
                  ],
                  onChanged: (v) =>
                      setState(() => _members[i] = SpaceMember(
                            name: _members[i].name,
                            role: v ?? 'view',
                            addedAt: _members[i].addedAt,
                          )),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _members.removeAt(i)),
                ),
              ],
            ),
          ),
        const Divider(),
        TextField(
          controller: _newName,
          decoration: const InputDecoration(labelText: '新成员昵称'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<String>(
              value: _newRole,
              items: const [
                DropdownMenuItem(value: 'manage', child: Text('管理')),
                DropdownMenuItem(value: 'edit', child: Text('编辑')),
                DropdownMenuItem(value: 'view', child: Text('查看')),
              ],
              onChanged: (v) => setState(() => _newRole = v ?? 'view'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                if (_newName.text.trim().isEmpty) return;
                setState(() => _members.add(SpaceMember(
                    name: _newName.text.trim(),
                    role: _newRole,
                    addedAt: DateTime.now())));
                _newName.clear();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加成员'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => widget.onMembers(_members),
          child: const Text('保存成员'),
        ),
        const SizedBox(height: 20),
        Text('修改空间密码', style: AppTheme.cardTitle(cs.onSurface)),
        const SizedBox(height: 8),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码（至少 6 位）'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () {
            if (_pass.text.length < 6) return;
            widget.onPassword(_pass.text);
          },
          child: const Text('修改密码（会生成新恢复码）'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
