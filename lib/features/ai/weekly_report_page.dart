import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../shared/widgets/common.dart';

/// 一份已生成的周报。
class WeeklyEntry {
  WeeklyEntry(this.at, this.text);

  final DateTime at;
  final String text;

  String get timeLabel {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '${at.year}年${at.month}月${at.day}日 $h:$m 生成';
  }

  /// 纯文本预览（剥 Markdown 标记）。
  String get preview =>
      text.replaceAll('#', '').replaceAll('*', '').replaceAll('\n', ' ').trim();

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'text': text};

  static WeeklyEntry fromJson(Map<String, dynamic> j) => WeeklyEntry(
      DateTime.parse(j['at'] as String), j['text'] as String);
}

/// AI 健康周报：最近 7 天数据 → Markdown 解读。
/// 历史持久化（每宠最多 30 份），进入默认显示最近一次，顶部注明生成时间。
class WeeklyReportPage extends ConsumerStatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  static const _storageKey = 'weeklyReports';
  static const _maxPerPet = 30;

  bool _loading = false;
  String? _error;
  List<WeeklyEntry> _history = [];
  int _viewIndex = 0;
  String? _loadedPetId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pet = ref.watch(currentPetProvider);
    final config = ref.watch(aiConfigProvider);

    // 宠物切换时重载历史。
    if (pet != null && _loadedPetId != pet.id) {
      _loadedPetId = pet.id;
      _loadHistory(pet.id);
    }

    final viewing =
        _history.isEmpty ? null : _history[_viewIndex.clamp(0, _history.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet?.name ?? ""}的健康周报'),
        actions: [
          if (_history.length > 1)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: '历史周报',
              onPressed: () => _showHistory(context),
            ),
        ],
      ),
      body: !config.isReady
          ? EmptyView(
              icon: Icons.key_outlined,
              title: 'AI 还没有配置',
              subtitle: '配置 API 后即可生成一周健康解读',
              action: FilledButton(
                onPressed: () => context.push('/settings/ai'),
                child: const Text('去配置'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (viewing == null)
                  FilledButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_loading ? '正在总结最近 7 天…' : '生成周报'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_loading ? '正在总结最近 7 天…' : '重新生成'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: AppTheme.footnote(AppTheme.warnRed)),
                ],
                if (viewing != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 13,
                                  color: cs.onSurfaceVariant),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(viewing.timeLabel,
                                    style: AppTheme.captionSm(
                                        cs.onSurfaceVariant)),
                              ),
                              if (_viewIndex > 0)
                                Text('历史第 ${_history.length - _viewIndex} 期',
                                    style: AppTheme.captionSm(
                                        cs.onSurfaceVariant)),
                            ],
                          ),
                          Divider(
                              height: 20,
                              color: cs.outlineVariant.withValues(alpha: 0.6)),
                          MarkdownBody(
                            data: viewing.text,
                            styleSheet: digestMarkdownStyle(context),
                            selectable: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (viewing == null && _error == null && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      '会汇总最近 7 天的体重、体型、健康事件、消费与喂食计划，生成一份带建议的健康周报。',
                      textAlign: TextAlign.center,
                      style: AppTheme.subhead(cs.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _loadHistory(String petId) async {
    final json = await ref.read(settingsRepoProvider).getJson(_storageKey);
    if (!mounted || _loadedPetId != petId) return;
    final list = (json?['reports'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final entries = [
      for (final e in list)
        if (e['petId'] == petId) WeeklyEntry.fromJson(e),
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (!mounted) return;
    setState(() {
      _history = entries;
      _viewIndex = 0;
      _error = null;
    });
  }

  Future<void> _persist(String petId, WeeklyEntry entry) async {
    final repo = ref.read(settingsRepoProvider);
    final json = await repo.getJson(_storageKey);
    final all = (json?['reports'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];
    all.insert(0, {'petId': petId, ...entry.toJson()});
    // 同一宠物只保留最近 30 份。
    var kept = 0;
    final trimmed = <Map<String, dynamic>>[
      for (final e in all)
        if (e['petId'] != petId || kept++ < _maxPerPet) e,
    ];
    await repo.setJson(_storageKey, {'reports': trimmed});
  }

  Future<void> _generate() async {
    final pet = ref.read(currentPetProvider);
    if (pet == null) {
      showAutoToast(context, '先添加一只宠物吧');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await ref.read(healthRepoProvider).getByPet(pet.id);
      final expenses = await ref.read(expenseRepoProvider).getAll();
      final plans = await ref
          .read(dietRepoProvider)
          .watchPlansByPet(pet.id)
          .first;
      final text = await ref.read(aiServiceProvider).weeklyReport(
            pet,
            records,
            expenses,
            plans.isEmpty ? null : plans.first,
          );
      final entry = WeeklyEntry(DateTime.now(), text);
      await _persist(pet.id, entry);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _history.insert(0, entry);
        _viewIndex = 0;
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxHeight: 460),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text('历史周报',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  itemBuilder: (context, i) {
                    final e = _history[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        i == _viewIndex
                            ? Icons.description_rounded
                            : Icons.description_outlined,
                        size: 20,
                        color: i == _viewIndex
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      title: Text(e.timeLabel,
                          style: AppTheme.subhead(cs.onSurface)),
                      subtitle: Text(
                        e.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.captionSm(cs.onSurfaceVariant),
                      ),
                      trailing: i == _viewIndex
                          ? Icon(Icons.check_rounded,
                              color: cs.primary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _viewIndex = i);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
