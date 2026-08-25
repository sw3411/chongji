import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/common.dart';

/// 备份与恢复：单文件 JSON（含图片），恢复前自动回滚备份。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _working = false;
  String? _message;

  Future<void> _export() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await ref.read(backupServiceProvider).export();
      setState(() => _message = '备份已导出（通过系统分享保存）');
    } catch (e) {
      setState(() => _message = '导出失败：$e');
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _restore({required bool overwrite}) async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null) {
        setState(() => _message = '未选择文件');
        return;
      }
      final file = picked.files.single;
      final bytes = file.bytes;
      if (file.path == null && bytes == null) {
        setState(() => _message = '未选择文件');
        return;
      }
      final content = bytes != null
          ? utf8.decode(bytes)
          : await File(file.path!).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final error = ref.read(backupServiceProvider).validate(data);
      if (error != null) {
        setState(() => _message = error);
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(overwrite ? '覆盖恢复？' : '合并恢复？'),
          content: Text(overwrite
              ? '当前全部数据将被备份文件替换（恢复前会自动生成回滚备份）。'
              : '备份中的记录将按 ID 合并进当前数据，重复的保留较新的。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始恢复')),
          ],
        ),
      );
      if (confirmed != true) return;

      final rollback = await ref
          .read(backupServiceProvider)
          .restore(data, overwrite: overwrite);
      setState(() => _message = rollback == null
          ? '恢复完成'
          : '恢复完成。若需回滚，可从临时文件恢复：$rollback');
    } catch (e) {
      setState(() => _message = '恢复失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cleanImages() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final referenced =
          await ref.read(backupServiceProvider).referencedImages();
      final removed = await ImageStore.cleanUnreferenced(referenced);
      setState(() => _message = removed == 0 ? '没有可清理的图片' : '已清理 $removed 张无引用图片');
    } catch (e) {
      setState(() => _message = '清理失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lastBackup = ref.watch(lastBackupAtProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: _working ? loadingView : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('导出备份',
                            style: AppTheme.cardTitle(cs.onSurface)),
                        const SizedBox(height: 6),
                        Text(
                          lastBackup == null
                              ? '还没备份过。备份包含全部记录、设置与照片，建议每月一次。'
                              : '上次备份：${Fmt.dateTime(lastBackup)}',
                          style: AppTheme.footnote(cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _export,
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text('导出备份文件'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('恢复', style: AppTheme.cardTitle(cs.onSurface)),
                        const SizedBox(height: 6),
                        Text(
                          '从备份文件恢复数据。覆盖模式会先自动生成当前数据的回滚备份。',
                          style: AppTheme.footnote(cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _restore(overwrite: false),
                                child: const Text('合并恢复'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.warnRed,
                                  side: const BorderSide(
                                      color: AppTheme.warnRed),
                                ),
                                onPressed: () => _restore(overwrite: true),
                                child: const Text('覆盖恢复'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: AppTheme.footnote(cs.onSurface)),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('图片空间', style: AppTheme.cardTitle(cs.onSurface)),
                        const SizedBox(height: 6),
                        FutureBuilder<int>(
                          future: ImageStore.storageUsage(),
                          builder: (context, snap) {
                            final usage = snap.data ?? 0;
                            return Text(
                              '照片与小票占用约 ${(usage / 1024 / 1024).toStringAsFixed(1)} MB，'
                              '可安全清理删除记录后残留的图片文件',
                              style: AppTheme.footnote(cs.onSurfaceVariant),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _working ? null : _cleanImages,
                          icon: const Icon(Icons.cleaning_services_outlined,
                              size: 18),
                          label: const Text('清理无引用图片'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '说明：备份不包含 AI API Key（安全考虑），恢复后请在 AI 设置中重新填写。',
                  style: AppTheme.caption(cs.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}
